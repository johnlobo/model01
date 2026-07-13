;;-----------------------------LICENSE NOTICE------------------------------------
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------

.module mem_system

.include "sys/mem.h.s"
.include "common.h.s"

;;
;; Start of _DATA area
;;
.area _DATA

sys_mem_is_128k::   .db 0       ;; 1 = 128K available, 0 = 64K only

;; Scratch byte for the 128K detection. It sits in _DATA, which the linker
;; places right after _CODE — i.e. inside &4000–&7FFF, the banking window.
;; That is load-bearing: the detection works precisely because writing here
;; while a bank is in lands in the EXTRA bank, not in normal RAM.
_smem_test_byte:    .db 0
_smem_test_save:    .db 0       ;; saves the original value of the test byte

;;------------------------------------------------------------------------------
;;
;;  Banking stub source bytes.
;;
;;  This 19-byte sequence is copied to SYS_MEM_STUB_ADDR (&0200) at init time.
;;  From there it can safely bank-in an extra RAM bank, run LDIR, and bank-out,
;;  even though the &4000–&7FFF window (where game code lives) is swapped out
;;  for the duration.
;;
;;  Calling convention (after copying to &0200):
;;    A  = banking configuration byte (SYS_MEM_BANK_CONFIG_BASE + bank)
;;    HL = source address
;;    DE = destination address
;;    BC = byte count
;;  Returns with normal banking restored. The RET is safe because banking is
;;  restored before the instruction executes, so the return address is always
;;  reachable even if the caller lives inside the window.
;;
;;  DI is NOT optional. int_handler1 lives in _CODE at &4000+, i.e. inside the
;;  window. An interrupt taken while the bank is in would vector through &0038
;;  into whatever the extra bank holds at the handler's address — a jump into
;;  garbage. The whole bank-in..bank-out span therefore runs under DI.
;;
;;  Stub disassembly:
;;    di                 ;  F3         — no interrupts while the window is swapped
;;    push bc            ;  C5         — save byte count (BC will be clobbered)
;;    ld bc, #&7F00      ;  01 00 7F   — banking port
;;    out (c), a         ;  ED 79      — switch to extra bank  ← window changes here
;;    pop bc             ;  C1         — restore byte count
;;    ldir               ;  ED B0      — copy BC bytes HL→DE  (reads from extra bank)
;;    ld a, #&C0         ;  3E C0      — SYS_MEM_BANK_NORMAL
;;    ld bc, #&7F00      ;  01 00 7F   — banking port
;;    out (c), a         ;  ED 79      — restore normal banking ← window restored here
;;    ei                 ;  FB
;;    ret                ;  C9         — safe: window is back to normal RAM
;;
;;  CRITICAL: the STACK must not live in &4000-&7FFF. The `push bc`/`pop bc`
;;  pair straddles the bank switch, so a stack inside the window would be
;;  swapped out between them and `pop bc` would read garbage from the extra
;;  bank. SP is set to &4000 in _main, so the stack sits below the window.
;;
_sys_mem_stub_src::
    .db 0xF3                ;; di
    .db 0xC5                ;; push bc
    .db 0x01, 0x00, 0x7F   ;; ld bc, #SYS_MEM_BANKING_PORT (&7F00)
    .db 0xED, 0x79          ;; out (c), a   → extra bank mapped in
    .db 0xC1                ;; pop bc
    .db 0xED, 0xB0          ;; ldir
    .db 0x3E, 0xC0          ;; ld a, #SYS_MEM_BANK_NORMAL (&C0)
    .db 0x01, 0x00, 0x7F   ;; ld bc, #SYS_MEM_BANKING_PORT (&7F00)
    .db 0xED, 0x79          ;; out (c), a   → normal banking restored
    .db 0xFB                ;; ei
    .db 0xC9                ;; ret
_sys_mem_stub_end::         ;; _sys_mem_stub_end - _sys_mem_stub_src = 19 bytes

;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_mem_init
;;
;;  Step 1 — Install the banking stub:
;;    Copy _sys_mem_stub_src (19 bytes) to SYS_MEM_STUB_ADDR (&0200).
;;    This is a plain LDIR with no banking; always safe.
;;
;;  Step 2 — Detect 128K RAM:
;;    Write &AA to _smem_test_byte, which the linker places in _DATA right after
;;      _CODE — i.e. inside &4000–&7FFF, the banking window. That is deliberate.
;;    Write &55 to SYS_MEM_DET_PATTERN_ADDR (&0213) — outside the window,
;;      one byte past the installed stub.
;;    Call the stub to copy that &55 byte into _smem_test_byte via extra bank 0.
;;      · While the stub executes: &4000–&7FFF = extra bank 0.
;;      · DE (_smem_test_byte) is in the window → the write lands IN EXTRA BANK.
;;      · HL (&0213) is outside the window → reads normal RAM (&55). ✓
;;      · After stub: normal banking restored, test byte back to normal RAM.
;;    If _smem_test_byte still holds &AA → extra bank is independent → 128K. ✓
;;    If it holds &55  → no independent banking → 64K only.
;;
;;  Input:  -
;;  Output: sys_mem_is_128k = 1 if 128K, 0 if 64K
;;  Modified: AF, BC, DE, HL
;;
sys_mem_init::
    ;; --- Step 1: copy stub to free low RAM at &0200 ---
    ld hl, #_sys_mem_stub_src
    ld de, #SYS_MEM_STUB_ADDR
    ld bc, #(_sys_mem_stub_end - _sys_mem_stub_src)
    ldir                            ;; plain copy, no banking

    ;; --- Step 2: detect 128K ---
    ;; Save the current value of the test byte so we can restore it
    ld a, (_smem_test_byte)
    ld (_smem_test_save), a

    ;; Write detection pattern &AA into normal RAM at the test byte
    ld a, #0xAA
    ld (_smem_test_byte), a

    ;; Write &55 just past the stub, outside the window so it survives the switch
    ld a, #0x55
    ld (SYS_MEM_DET_PATTERN_ADDR), a

    ;; Call the stub to copy that &55 byte to the test byte in extra bank 0.
    ld a, #SYS_MEM_BANK_CONFIG_BASE     ;; bank 0 (config 4 = &C4)
    ld hl, #SYS_MEM_DET_PATTERN_ADDR    ;; source: &55, outside the window (&0213)
    ld de, #_smem_test_byte             ;; dest:   inside the window → extra bank
    ld bc, #1
    call SYS_MEM_STUB_ADDR              ;; stub at &0200 — safe

    ;; Read the test address back from normal RAM (stub restored normal banking)
    ;; &AA → write went to the extra bank (independent) → 128K confirmed
    ;; &55 → write went to normal RAM (same physical memory) → 64K only
    ld a, (_smem_test_byte)
    cp #0xAA
    ld a, #0
    jr nz, _smi_no128k
    inc a                               ;; a = 1: 128K confirmed
_smi_no128k:
    ld (sys_mem_is_128k), a

    ;; Restore the original test byte value
    ld a, (_smem_test_save)
    ld (_smem_test_byte), a
    ret

;;-----------------------------------------------------------------
;;
;; sys_mem_copy_from_bank
;;
;;  Copy BC bytes from extra RAM bank A into normal RAM at DE.
;;  Delegates entirely to the stub at SYS_MEM_STUB_ADDR (&0200) so it
;;  is safe to call from any address, including &4000–&7FFF.
;;
;;  Execution trace:
;;    1. This routine adds the bank offset to A and calls &0200.
;;    2. Stub runs from &0200 (free low RAM):
;;         banks in → HL reads from extra bank → LDIR fills DE → banks out → ret
;;    3. RET returns here (normal banking restored) → RET returns to caller.
;;
;;  CONSTRAINT: DE must not point into &4000–&7FFF. If it did, the write
;;  would land in the extra bank instead of normal RAM.
;;
;;  Input:  A  = extra bank (0–3)
;;          HL = source address in bank (&4000–&7FFF range)
;;          DE = destination in normal RAM (must not be &4000–&7FFF)
;;          BC = byte count
;;  Output: -
;;  Modified: AF, BC, DE, HL
;;
sys_mem_copy_from_bank::
    add a, #SYS_MEM_BANK_CONFIG_BASE   ;; A = &C4..&C7
    call SYS_MEM_STUB_ADDR
    ret

;;-----------------------------------------------------------------
;;
;; sys_mem_copy_to_bank
;;
;;  Copy BC bytes from normal RAM at HL into extra RAM bank A at DE.
;;  Delegates to the stub at &0200 — safe from any address.
;;
;;  CONSTRAINT: HL must not point into &4000–&7FFF. If it did, the read
;;  would come from the extra bank instead of normal RAM.
;;
;;  Input:  A  = extra bank (0–3)
;;          HL = source in normal RAM (must not be &4000–&7FFF)
;;          DE = destination address in bank (&4000–&7FFF range)
;;          BC = byte count
;;  Output: -
;;  Modified: AF, BC, DE, HL
;;
sys_mem_copy_to_bank::
    add a, #SYS_MEM_BANK_CONFIG_BASE   ;; A = &C4..&C7
    call SYS_MEM_STUB_ADDR
    ret

;;-----------------------------------------------------------------
;;
;; sys_mem_bank_in  [LOW-LEVEL]
;;
;;  Map extra bank A into &4000–&7FFF and return.
;;  !! ONLY SAFE when this routine is NOT in the &4000–&7FFF region. !!
;;  After the OUT instruction the window is swapped; the RET opcode
;;  that follows is now in the extra bank — if it contains garbage,
;;  execution will go haywire. This function is only reliable when
;;  called from code above &7FFF (e.g. a loader at &8000+).
;;
;;  Typical use: from a one-time loader living above &7FFF, bank in,
;;  bulk-write data directly to &4000–&7FFF, then call bank_out.
;;  For all in-game data transfers, prefer sys_mem_copy_to/from_bank.
;;
;;  Input:  A = extra bank (0–3)
;;  Output: -
;;  Modified: AF, BC
;;
sys_mem_bank_in::
    add a, #SYS_MEM_BANK_CONFIG_BASE
    ld bc, #SYS_MEM_BANKING_PORT
    out (c), a
    ret

;;-----------------------------------------------------------------
;;
;; sys_mem_bank_out  [LOW-LEVEL]
;;
;;  Restore normal banking (&4000–&7FFF = normal game RAM).
;;  !! Only safe when called from code NOT executing from the &4000–&7FFF
;;  window while it is swapped out. !!
;;
;;  Input:  -
;;  Output: -
;;  Modified: AF, BC
;;
sys_mem_bank_out::
    ld a, #SYS_MEM_BANK_NORMAL
    ld bc, #SYS_MEM_BANKING_PORT
    out (c), a
    ret
