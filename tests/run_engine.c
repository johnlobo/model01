#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "z80ex.h"

enum {
    MEMORY_SIZE = 65536,
    LOAD_ADDRESS = 0x4000,
    RETURN_ADDRESS = 0x0080,
    STACK_ADDRESS = 0xf000,
    TEST_MAP_ADDRESS = 0x2000,
    MAP_WIDTH = 16,
    MAP_HEIGHT = 20,
    MAX_STEPS = 1000000,
    ARRAY_COUNT = 0,
    ARRAY_MAX_COUNT = 1,
    ARRAY_COMPONENT_SIZE = 2,
    ARRAY_PEND = 3,
    ARRAY_DATA = 7,
    ENTITY_SIZE = 31,
    E_CMPS = 0,
    E_STATUS = 1,
    E_X = 2,
    E_Y = 3,
    E_SPEED_X = 12,
    E_SPRITE = 20,
    E_MOVED = 22,
    E_ANIM = 23,
    E_ANIM_FRAME = 25,
    E_ANIM_TIMER = 26,
    E_BEH_TIMER = 29,
    E_ROOM = 30,
    MAX_ENTITIES = 20,
    STATUS_PLAYER_BULLET = 4
};

struct Symbols {
    uint16_t entities;
    uint16_t entity_array;
    uint16_t object_template;
    uint16_t portal_template;
    uint16_t player_bullet_template;
    uint16_t create_object;
    uint16_t create_portal;
    uint16_t create_player_bullet;
    uint16_t shoot_update_one_bullet;
    uint16_t current_map_data;
    uint16_t current_room;
    uint16_t anim_set;
    uint16_t idle_anim;
    uint16_t walk_right_anim;
    uint16_t monk_0;
    uint16_t monk_2;
};

struct Machine {
    uint8_t memory[MEMORY_SIZE];
    uint8_t image[MEMORY_SIZE];
    struct Symbols symbols;
    Z80EX_CONTEXT *cpu;
};

static int tests_run;
static int tests_failed;

static Z80EX_BYTE memory_read(Z80EX_CONTEXT *cpu, Z80EX_WORD address,
                              int m1_state, void *user_data) {
    struct Machine *machine = user_data;
    (void)cpu;
    (void)m1_state;
    return machine->memory[address];
}

static void memory_write(Z80EX_CONTEXT *cpu, Z80EX_WORD address,
                         Z80EX_BYTE value, void *user_data) {
    struct Machine *machine = user_data;
    (void)cpu;
    machine->memory[address] = value;
}

static Z80EX_BYTE port_read(Z80EX_CONTEXT *cpu, Z80EX_WORD port,
                            void *user_data) {
    (void)cpu; (void)port; (void)user_data;
    return 0xff;
}

static void port_write(Z80EX_CONTEXT *cpu, Z80EX_WORD port,
                       Z80EX_BYTE value, void *user_data) {
    (void)cpu; (void)port; (void)value; (void)user_data;
}

static Z80EX_BYTE interrupt_read(Z80EX_CONTEXT *cpu, void *user_data) {
    (void)cpu; (void)user_data;
    return 0xff;
}

static void die(const char *message, const char *path) {
    if (path) fprintf(stderr, "%s: %s: %s\n", message, path, strerror(errno));
    else fprintf(stderr, "%s\n", message);
    exit(EXIT_FAILURE);
}

static void load_binary(struct Machine *machine, const char *path) {
    FILE *file = fopen(path, "rb");
    size_t capacity = MEMORY_SIZE - LOAD_ADDRESS;
    size_t size;
    if (!file) die("cannot open game binary", path);
    size = fread(machine->image + LOAD_ADDRESS, 1, capacity, file);
    if (ferror(file)) die("cannot read game binary", path);
    if (!feof(file)) die("game binary does not fit in Z80 memory", NULL);
    fclose(file);
    if (!size) die("game binary is empty", NULL);
}

static uint16_t *symbol_slot(struct Symbols *symbols, const char *name) {
    if (!strcmp(name, "entities")) return &symbols->entities;
    if (!strcmp(name, "entity_array")) return &symbols->entity_array;
    if (!strcmp(name, "object_template")) return &symbols->object_template;
    if (!strcmp(name, "portal_template")) return &symbols->portal_template;
    if (!strcmp(name, "player_bullet_template")) return &symbols->player_bullet_template;
    if (!strcmp(name, "man_entity_create_object")) return &symbols->create_object;
    if (!strcmp(name, "man_entity_create_portal")) return &symbols->create_portal;
    if (!strcmp(name, "man_entity_create_player_bullet")) return &symbols->create_player_bullet;
    if (!strcmp(name, "sys_shoot_update_one_bullet")) return &symbols->shoot_update_one_bullet;
    if (!strcmp(name, "current_map_data")) return &symbols->current_map_data;
    if (!strcmp(name, "current_room")) return &symbols->current_room;
    if (!strcmp(name, "sys_anim_set")) return &symbols->anim_set;
    if (!strcmp(name, "monk_idle_anim")) return &symbols->idle_anim;
    if (!strcmp(name, "monk_walk_right_anim")) return &symbols->walk_right_anim;
    if (!strcmp(name, "_s_monk_0")) return &symbols->monk_0;
    if (!strcmp(name, "_s_monk_2")) return &symbols->monk_2;
    return NULL;
}

static void load_symbols(struct Machine *machine, const char *path) {
    FILE *file = fopen(path, "r");
    char line[256], name[128];
    unsigned address;
    const uint16_t *values = (const uint16_t *)&machine->symbols;
    size_t i;
    if (!file) die("cannot open linker symbols", path);
    while (fgets(line, sizeof line, file)) {
        uint16_t *slot;
        if (sscanf(line, "DEF %127s 0x%x", name, &address) != 2) continue;
        slot = symbol_slot(&machine->symbols, name);
        if (slot && address < MEMORY_SIZE) *slot = (uint16_t)address;
    }
    fclose(file);
    for (i = 0; i < sizeof machine->symbols / sizeof *values; ++i) {
        if (!values[i]) die("one or more required symbols are missing from the .noi file", NULL);
    }
}

static void reset_fixture(struct Machine *machine) {
    memcpy(machine->memory, machine->image, MEMORY_SIZE);
    machine->memory[RETURN_ADDRESS] = 0x76; /* HALT */
    z80ex_reset(machine->cpu);
}

static void set_word(uint8_t *memory, uint16_t address, uint16_t value) {
    memory[address] = value & 0xff;
    memory[address + 1] = value >> 8;
}

static uint16_t get_word(const uint8_t *memory, uint16_t address) {
    return memory[address] | ((uint16_t)memory[address + 1] << 8);
}

static int run_routine(struct Machine *machine, uint16_t address) {
    unsigned steps;
    uint16_t sp = STACK_ADDRESS - 2;
    machine->memory[sp] = RETURN_ADDRESS & 0xff;
    machine->memory[sp + 1] = RETURN_ADDRESS >> 8;
    z80ex_set_reg(machine->cpu, regSP, sp);
    z80ex_set_reg(machine->cpu, regPC, address);
    for (steps = 0; steps < MAX_STEPS; ++steps) {
        z80ex_step(machine->cpu);
        if (z80ex_doing_halt(machine->cpu))
            return (z80ex_get_reg(machine->cpu, regAF) & 1) != 0;
    }
    die("Z80 routine did not return before the instruction limit", NULL);
    return 1;
}

static int call_factory(struct Machine *machine, uint16_t routine,
                        uint8_t x, uint8_t y, uint8_t room, uint8_t speed) {
    z80ex_set_reg(machine->cpu, regBC, ((uint16_t)x << 8) | y);
    z80ex_set_reg(machine->cpu, regDE, ((uint16_t)room << 8) | speed);
    return run_routine(machine, routine);
}

static void report(const char *name, int passed) {
    ++tests_run;
    if (passed) printf("ok %d - %s\n", tests_run, name);
    else {
        ++tests_failed;
        printf("not ok %d - %s\n", tests_run, name);
    }
}

static void test_valid_bullet(struct Machine *machine) {
    uint16_t entity;
    reset_fixture(machine);
    report("a valid projectile is created",
           !call_factory(machine, machine->symbols.create_player_bullet, 60, 40, 2, 2) &&
           machine->memory[machine->symbols.entities + ARRAY_COUNT] == 1 &&
           (entity = machine->symbols.entity_array) != 0 &&
           machine->memory[entity + E_STATUS] == STATUS_PLAYER_BULLET &&
           machine->memory[entity + E_X] == 60 &&
           machine->memory[entity + E_Y] == 40 &&
           machine->memory[entity + E_ROOM] == 2 &&
           machine->memory[entity + E_SPEED_X] == 2);
}

static void test_invalid_bullets(struct Machine *machine) {
    reset_fixture(machine);
    report("a wrapped left-edge projectile is rejected",
           call_factory(machine, machine->symbols.create_player_bullet, 0xfc, 40, 0, 0xfe) &&
           machine->memory[machine->symbols.entities + ARRAY_COUNT] == 0);
    reset_fixture(machine);
    report("a right-edge projectile that does not fit is rejected",
           call_factory(machine, machine->symbols.create_player_bullet, 61, 40, 0, 2) &&
           machine->memory[machine->symbols.entities + ARRAY_COUNT] == 0);
}

static uint16_t prepare_bullet_map(struct Machine *machine, uint8_t x,
                                   uint8_t y, uint8_t speed) {
    uint16_t entity = machine->symbols.entity_array;
    reset_fixture(machine);
    memset(machine->memory + TEST_MAP_ADDRESS, 0, MAP_WIDTH * MAP_HEIGHT);
    set_word(machine->memory, machine->symbols.current_map_data, TEST_MAP_ADDRESS);
    machine->memory[machine->symbols.current_room] = 0;
    if (call_factory(machine, machine->symbols.create_player_bullet,
                     x, y, 0, speed))
        die("test projectile creation failed", NULL);
    machine->memory[entity + E_BEH_TIMER] = 0;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, entity);
    return entity;
}

static void test_bullet_tile_collision(struct Machine *machine) {
    uint16_t entity;

    entity = prepare_bullet_map(machine, 12, 32, 2);
    run_routine(machine, machine->symbols.shoot_update_one_bullet);
    report("a projectile moves through passable tiles",
           machine->memory[entity + E_CMPS] != 0 &&
           machine->memory[entity + E_X] == 14 &&
           machine->memory[entity + E_MOVED] == 1);

    entity = prepare_bullet_map(machine, 12, 32, 2);
    machine->memory[TEST_MAP_ADDRESS + 4 * MAP_WIDTH + 4] = 2;
    run_routine(machine, machine->symbols.shoot_update_one_bullet);
    report("a right-moving projectile is destroyed by a solid tile",
           machine->memory[entity + E_CMPS] == 0 &&
           machine->memory[entity + E_X] == 12);

    entity = prepare_bullet_map(machine, 20, 32, 0xfe);
    machine->memory[TEST_MAP_ADDRESS + 4 * MAP_WIDTH + 4] = 1;
    run_routine(machine, machine->symbols.shoot_update_one_bullet);
    report("a left-moving projectile is destroyed by a one-way platform",
           machine->memory[entity + E_CMPS] == 0 &&
           machine->memory[entity + E_X] == 20);
}

static void test_factory_parameters(struct Machine *machine) {
    uint16_t entity;
    reset_fixture(machine);
    entity = machine->symbols.entity_array;
    report("object creation preserves x, y and room",
           !call_factory(machine, machine->symbols.create_object, 12, 34, 3, 0) &&
           machine->memory[entity + E_X] == 12 &&
           machine->memory[entity + E_Y] == 34 &&
           machine->memory[entity + E_ROOM] == 3);
    reset_fixture(machine);
    report("portal creation preserves x, y and room",
           !call_factory(machine, machine->symbols.create_portal, 20, 88, 2, 0) &&
           machine->memory[entity + E_X] == 20 &&
           machine->memory[entity + E_Y] == 88 &&
           machine->memory[entity + E_ROOM] == 2);
}

static void saturate_pool(struct Machine *machine, int recyclable_first) {
    uint16_t base = machine->symbols.entities;
    int i;
    machine->memory[base + ARRAY_COUNT] = MAX_ENTITIES;
    machine->memory[base + ARRAY_MAX_COUNT] = MAX_ENTITIES;
    machine->memory[base + ARRAY_COMPONENT_SIZE] = ENTITY_SIZE;
    set_word(machine->memory, base + ARRAY_PEND,
             machine->symbols.entity_array + MAX_ENTITIES * ENTITY_SIZE);
    for (i = 0; i < MAX_ENTITIES; ++i)
        machine->memory[machine->symbols.entity_array + i * ENTITY_SIZE + E_CMPS] = 1;
    if (recyclable_first) machine->memory[machine->symbols.entity_array + E_CMPS] = 0;
}

static void test_pool_contract(struct Machine *machine) {
    uint8_t before[ENTITY_SIZE];
    reset_fixture(machine);
    saturate_pool(machine, 0);
    memcpy(before, machine->memory + machine->symbols.object_template, ENTITY_SIZE);
    report("a full pool is reported without corrupting the template",
           call_factory(machine, machine->symbols.create_object, 12, 34, 3, 0) &&
           !memcmp(before, machine->memory + machine->symbols.object_template, ENTITY_SIZE));

    reset_fixture(machine);
    saturate_pool(machine, 1);
    report("a dead slot is recycled even when count equals capacity",
           !call_factory(machine, machine->symbols.create_player_bullet, 10, 40, 1, 2) &&
           machine->memory[machine->symbols.entities + ARRAY_COUNT] == MAX_ENTITIES &&
           machine->memory[machine->symbols.entity_array + E_STATUS] == STATUS_PLAYER_BULLET);
}

static void test_animation_set(struct Machine *machine) {
    uint16_t entity = machine->symbols.entity_array;
    reset_fixture(machine);
    set_word(machine->memory, entity + E_ANIM, machine->symbols.walk_right_anim);
    set_word(machine->memory, entity + E_SPRITE, machine->symbols.monk_2);
    machine->memory[entity + E_ANIM_FRAME] = 2;
    machine->memory[entity + E_ANIM_TIMER] = 4;
    z80ex_set_reg(machine->cpu, regIX, entity);
    z80ex_set_reg(machine->cpu, regHL, machine->symbols.idle_anim);
    report("changing animation applies its first frame immediately",
           !run_routine(machine, machine->symbols.anim_set) &&
           get_word(machine->memory, entity + E_ANIM) == machine->symbols.idle_anim &&
           get_word(machine->memory, entity + E_SPRITE) == machine->symbols.monk_0 &&
           machine->memory[entity + E_ANIM_FRAME] == 0 &&
           machine->memory[entity + E_ANIM_TIMER] == 0 &&
           machine->memory[entity + E_MOVED] == 1);

    reset_fixture(machine);
    set_word(machine->memory, entity + E_ANIM, machine->symbols.walk_right_anim);
    set_word(machine->memory, entity + E_SPRITE, machine->symbols.monk_2);
    machine->memory[entity + E_ANIM_FRAME] = 2;
    machine->memory[entity + E_ANIM_TIMER] = 4;
    z80ex_set_reg(machine->cpu, regIX, entity);
    z80ex_set_reg(machine->cpu, regHL, machine->symbols.walk_right_anim);
    report("setting the current animation does not restart it",
           !run_routine(machine, machine->symbols.anim_set) &&
           machine->memory[entity + E_ANIM_FRAME] == 2 &&
           machine->memory[entity + E_ANIM_TIMER] == 4 &&
           get_word(machine->memory, entity + E_SPRITE) == machine->symbols.monk_2);
}

int main(int argc, char **argv) {
    struct Machine machine;
    if (argc != 3) {
        fprintf(stderr, "usage: %s GAME.bin GAME.noi\n", argv[0]);
        return EXIT_FAILURE;
    }
    memset(&machine, 0, sizeof machine);
    load_binary(&machine, argv[1]);
    load_symbols(&machine, argv[2]);
    machine.cpu = z80ex_create(memory_read, &machine, memory_write, &machine,
                               port_read, &machine, port_write, &machine,
                               interrupt_read, &machine);
    if (!machine.cpu) die("cannot create Z80 emulator", NULL);
    printf("TAP version 13\n");
    test_valid_bullet(&machine);
    test_invalid_bullets(&machine);
    test_bullet_tile_collision(&machine);
    test_factory_parameters(&machine);
    test_pool_contract(&machine);
    test_animation_set(&machine);
    printf("1..%d\n", tests_run);
    z80ex_destroy(machine.cpu);
    if (tests_failed) {
        fprintf(stderr, "%d of %d tests failed\n", tests_failed, tests_run);
        return EXIT_FAILURE;
    }
    printf("All %d Z80 engine tests passed.\n", tests_run);
    return EXIT_SUCCESS;
}
