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

;;==============================================================================
;;  sys/mem.h.s  —  Extended memory system for Amstrad CPC 6128 (128K RAM)
;;
;;  The CPC 6128 has 128KB RAM: the standard 64KB plus 64KB of extra RAM
;;  divided into four 16KB banks (extra banks 0–3). The Gate Array maps
;;  one extra bank at a time into the &4000–&7FFF window via I/O port &7F00.
;;
;;  Common 64K memory map (Z80CODELOC = &4000):
;;    &0000–&003F   RST vectors (&0038 = IM1 interrupt entry)
;;    &0040–&00FF   Reserved low RAM
;;    &0100–&01FF   Transparency table (256-byte aligned)
;;    &0200–&0214   Banking stub + detection scratch bytes
;;    &0215–&02FF   Free low RAM
;;    &0300–&0EB7   Message background buffer
;;    &0EB8–&3FFF   Shared streaming workspace (64K and 128K content)
;;    &4000–&7FFF   Game code + data — AND the 128K banking WINDOW
;;    &8000–&BFFF   Reserved back buffer / current stack near &BFxx
;;    &C000–&FFFF   Front buffer
;;
;;  Banking window: &4000–&7FFF  (16KB, banking configs 4–7)
;;
;;  SAFETY — two things must live OUTSIDE the window while a bank is in:
;;
;;   1. THE BANKING CODE ITSELF. Game code is at &4000–&7FFF, so a routine that
;;      banked in from there would vanish mid-execution. Hence the stub, copied
;;      to &0200 at init; all copy operations run from there.
;;
;;   2. THE INTERRUPT PATH. An interrupt taken while the window is swapped out
;;      jumps via &0038 to int_handler1 — which lives at &4000+ and is therefore
;;      NOT THERE. That is a jump into whatever bytes the extra bank happens to
;;      hold: a crash. The stub therefore runs the whole bank-in..bank-out span
;;      under DI. Do not remove it.
;;
;;  The firmware stack (~&BFxx) is already outside the window, so push/pop across
;;  the bank switch is safe. If you ever relocate SP, keep it out of &4000–&7FFF.
;;==============================================================================

;;------------------------------------------------------------------------------
;; Constants
;;------------------------------------------------------------------------------

SYS_MEM_BANKING_PORT     = 0x7F00  ;; Gate Array banking port (upper byte must be &7F)
SYS_MEM_BANK_NORMAL      = 0xC0    ;; Config 0: normal 64KB layout
SYS_MEM_BANK_CONFIG_BASE = 0xC4    ;; Configs 4–7: extra banks 0–3 at &4000–&7FFF
SYS_MEM_NUM_EXTRA_BANKS  = 4       ;; number of switchable extra banks
SYS_MEM_WINDOW_START     = 0x4000  ;; start of the banking window
SYS_MEM_WINDOW_SIZE      = 0x4000  ;; size of each bank / the window (16KB)

;; Machine capability returned by sys_mem_detect and stored in
;; sys_mem_is_128k. Values are deliberately boolean for cheap OR/JR tests.
SYS_MEM_CAPACITY_64K     = 0
SYS_MEM_CAPACITY_128K    = 1

;; Stable regions in the common 64K address space. Games may subdivide the
;; streaming workspace, but must not overlap the fixed users around it.
SYS_MEM_RST_START        = 0x0000
SYS_MEM_RST_SIZE         = 0x0040
SYS_MEM_TRANSPARENCY_ADDR = 0x0100
SYS_MEM_TRANSPARENCY_SIZE = 0x0100
SYS_MEM_LOW_FREE_START   = 0x0215
SYS_MEM_LOW_FREE_SIZE    = 0x00EB
SYS_MEM_MESSAGE_START    = 0x0300
SYS_MEM_MESSAGE_SIZE     = 3000
SYS_MEM_STREAM_START     = SYS_MEM_MESSAGE_START + SYS_MEM_MESSAGE_SIZE ;; &0EB8
SYS_MEM_STREAM_SIZE      = SYS_MEM_WINDOW_START - SYS_MEM_STREAM_START  ;; &3148
SYS_MEM_BACK_BUFFER      = 0x8000
SYS_MEM_FRONT_BUFFER     = 0xC000

;; Fixed address for the banking stub, in the free low RAM just above the
;; transparency table (&0100–&01FF) and far below _CODE (&4000). Must stay
;; outside &4000–&7FFF so it survives the bank switch it performs.
SYS_MEM_STUB_ADDR        = 0x0200

;; The banking stub is 19 bytes (see mem.s — 17 for the copy, +2 for DI/EI).
;; Detection uses &0213 for its pattern and &0214 to preserve the byte that
;; bank 0 normally exposes at _smem_test_byte. Both remain outside the window.
SYS_MEM_STUB_SIZE        = 19
SYS_MEM_DET_PATTERN_ADDR = SYS_MEM_STUB_ADDR + SYS_MEM_STUB_SIZE  ;; &0213
SYS_MEM_DET_SAVE_ADDR    = SYS_MEM_DET_PATTERN_ADDR + 1            ;; &0214

;;------------------------------------------------------------------------------
;; Public variables
;;------------------------------------------------------------------------------

;; 1 if the machine has 128KB RAM (CPC 6128 or compatible), 0 if 64KB only.
;; Set by sys_mem_init/sys_mem_detect. Copy routines also check it themselves.

;;------------------------------------------------------------------------------
;; Public routines
;;------------------------------------------------------------------------------

;; sys_mem_init
;;   Compatibility initialization entry point. Calls sys_mem_detect.
;;   Call once at startup before any other sys_mem routine.

;; sys_mem_detect
;;   Install/refresh the low-RAM banking stub and detect available RAM.
;;   Safe to call more than once; restores the test byte in normal RAM.
;;   Output: A=SYS_MEM_CAPACITY_128K and Z=0 on 128K machines;
;;           A=SYS_MEM_CAPACITY_64K and Z=1 on 64K machines;
;;           carry clear in both cases. Also updates sys_mem_is_128k.
;;   Modified: AF, BC, DE, HL

;; sys_mem_copy_from_bank
;;   Copy BC bytes from extra RAM bank A into normal RAM.
;;   SAFE from &4000–&7FFF code (executes through stub at &0200).
;;   CONSTRAINT: DE (destination) must NOT be in &4000–&7FFF.
;;   Input:  A  = extra bank (0–3)
;;           HL = source address in bank (&4000–&7FFF range)
;;           DE = destination in normal RAM
;;           BC = byte count (1–16384)
;;   Output: carry clear on success; carry set on 64K or invalid bank
;;   Modified: AF, BC, DE, HL

;; sys_mem_copy_to_bank
;;   Copy BC bytes from normal RAM into extra RAM bank A.
;;   SAFE from &4000–&7FFF code (executes through stub at &0200).
;;   CONSTRAINT: HL (source) must NOT be in &4000–&7FFF.
;;   Input:  A  = extra bank (0–3)
;;           HL = source in normal RAM
;;           DE = destination address in bank (&4000–&7FFF range)
;;           BC = byte count (1–16384)
;;   Output: carry clear on success; carry set on 64K or invalid bank
;;   Modified: AF, BC, DE, HL

;; sys_mem_bank_in  [LOW-LEVEL — UNSAFE FROM &4000–&7FFF CODE]
;;   Map extra RAM bank A into the &4000–&7FFF window.
;;   Only call from code that resides OUTSIDE &4000–&7FFF (e.g. loaders at &8000+).
;;   Must be followed by sys_mem_bank_out before any &4000+ code can run.
;;   Input:  A = extra bank (0–3)
;;   Modified: AF, BC

;; sys_mem_bank_out  [LOW-LEVEL — UNSAFE WHILE BANK IS IN]
;;   Restore normal banking (&4000–&7FFF = normal game RAM).
;;   Only safe to call when you are certain the code executing it is
;;   NOT in the &4000–&7FFF range.
;;   Modified: AF, BC
