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
    TEST_ARRAY_SOURCE = 0x2200,
    TEST_ARRAY_DESTINATION = 0x2300,
    TEST_COLLIDER = 0x2400,
    TEST_COLLISIONABLE = 0x2440,
    TEST_BEHAVIOR = 0x2500,
    TEST_BEHAVIOR_ENTITY = 0x2600,
    TEST_INTERACTION_HANDLER = 0x2700,
    TEST_INTERACTION_FILTER = 0x2710,
    TEST_INTERACTION_MARKER = 0x2720,
    TEST_SCRIPT = 0x2800,
    TEST_SCRIPT_CALLBACK = 0x2900,
    TEST_SCRIPT_MARKER = 0x2910,
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
    E_SPEED_Y = 14,
    E_ON_AIR = 16,
    E_WIDTH = 17,
    E_HEIGHT = 18,
    E_SPRITE = 20,
    E_MOVED = 22,
    E_ANIM = 23,
    E_ANIM_FRAME = 25,
    E_ANIM_TIMER = 26,
    E_BEH = 27,
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
    uint16_t create_player;
    uint16_t create_object;
    uint16_t create_portal;
    uint16_t create_player_bullet;
    uint16_t create_chaser_enemy;
    uint16_t create_position_patrol_enemy;
    uint16_t create_flying_enemy;
    uint16_t shoot_update_one_bullet;
    uint16_t current_map_data;
    uint16_t current_room;
    uint16_t tile_solid_table;
    uint16_t tileset;
    uint16_t map_init;
    uint16_t map_set_collision_table;
    uint16_t map_get_tile;
    uint16_t map_set_tile;
    uint16_t map_set_tile_and_redraw;
    uint16_t map_is_solid;
    uint16_t array_init;
    uint16_t array_remove;
    uint16_t array_get;
    uint16_t array_move_all;
    uint16_t collision_init;
    uint16_t collision_set_handler;
    uint16_t collision_on_hit;
    uint16_t game_collision_handler;
    uint16_t game_collision_init;
    uint16_t beh_update_one;
    uint16_t beh_action_idle;
    uint16_t beh_action_set_vx;
    uint16_t beh_cond_true;
    uint16_t beh_actions_left;
    uint16_t anim_set;
    uint16_t physics_update_one;
    uint16_t idle_anim;
    uint16_t walk_right_anim;
    uint16_t monk_0;
    uint16_t monk_2;
    uint16_t state_flags;
    uint16_t state_counters;
    uint16_t state_init;
    uint16_t state_set_flag;
    uint16_t state_clear_flag;
    uint16_t state_test_flag;
    uint16_t state_get_counter;
    uint16_t state_set_counter;
    uint16_t state_add_counter;
    uint16_t state_sub_counter;
    uint16_t inventory_count;
    uint16_t inventory_items;
    uint16_t inventory_init;
    uint16_t inventory_add;
    uint16_t inventory_remove;
    uint16_t inventory_contains;
    uint16_t inventory_get;
    uint16_t interaction_init;
    uint16_t interaction_set_filter;
    uint16_t interaction_set_handler;
    uint16_t interaction_find;
    uint16_t interaction_try;
    uint16_t script_pc;
    uint16_t script_ops_left;
    uint16_t script_init;
    uint16_t script_start;
    uint16_t script_update;
    uint16_t script_is_running;
    uint16_t mem_is_128k;
    uint16_t mem_detect;
    uint16_t mem_copy_from_bank;
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
    if (!strcmp(name, "game_object_template")) return &symbols->object_template;
    if (!strcmp(name, "game_portal_template")) return &symbols->portal_template;
    if (!strcmp(name, "game_player_bullet_template")) return &symbols->player_bullet_template;
    if (!strcmp(name, "game_entity_create_player")) return &symbols->create_player;
    if (!strcmp(name, "game_entity_create_object")) return &symbols->create_object;
    if (!strcmp(name, "game_entity_create_portal")) return &symbols->create_portal;
    if (!strcmp(name, "game_entity_create_player_bullet")) return &symbols->create_player_bullet;
    if (!strcmp(name, "game_entity_create_chaser_enemy")) return &symbols->create_chaser_enemy;
    if (!strcmp(name, "game_entity_create_position_patrol_enemy")) return &symbols->create_position_patrol_enemy;
    if (!strcmp(name, "game_entity_create_flying_enemy")) return &symbols->create_flying_enemy;
    if (!strcmp(name, "sys_shoot_update_one_bullet")) return &symbols->shoot_update_one_bullet;
    if (!strcmp(name, "current_map_data")) return &symbols->current_map_data;
    if (!strcmp(name, "current_room")) return &symbols->current_room;
    if (!strcmp(name, "game_tile_solid_table")) return &symbols->tile_solid_table;
    if (!strcmp(name, "_s_tileset_00")) return &symbols->tileset;
    if (!strcmp(name, "sys_map_init")) return &symbols->map_init;
    if (!strcmp(name, "sys_map_set_collision_table")) return &symbols->map_set_collision_table;
    if (!strcmp(name, "sys_map_get_tile")) return &symbols->map_get_tile;
    if (!strcmp(name, "sys_map_set_tile")) return &symbols->map_set_tile;
    if (!strcmp(name, "sys_map_set_tile_and_redraw")) return &symbols->map_set_tile_and_redraw;
    if (!strcmp(name, "sys_map_is_solid_at")) return &symbols->map_is_solid;
    if (!strcmp(name, "sys_array_init")) return &symbols->array_init;
    if (!strcmp(name, "sys_array_remove_element")) return &symbols->array_remove;
    if (!strcmp(name, "sys_array_get_element")) return &symbols->array_get;
    if (!strcmp(name, "sys_array_move_all_elements")) return &symbols->array_move_all;
    if (!strcmp(name, "sys_collision_init")) return &symbols->collision_init;
    if (!strcmp(name, "sys_collision_set_handler")) return &symbols->collision_set_handler;
    if (!strcmp(name, "sys_collision_on_hit")) return &symbols->collision_on_hit;
    if (!strcmp(name, "game_collision_on_hit")) return &symbols->game_collision_handler;
    if (!strcmp(name, "game_collision_init")) return &symbols->game_collision_init;
    if (!strcmp(name, "sys_beh_update_one_entity")) return &symbols->beh_update_one;
    if (!strcmp(name, "beh_action_idle")) return &symbols->beh_action_idle;
    if (!strcmp(name, "beh_action_set_vx")) return &symbols->beh_action_set_vx;
    if (!strcmp(name, "beh_cond_true")) return &symbols->beh_cond_true;
    if (!strcmp(name, "sys_beh_actions_left")) return &symbols->beh_actions_left;
    if (!strcmp(name, "sys_anim_set")) return &symbols->anim_set;
    if (!strcmp(name, "sys_physics_update_one_entity")) return &symbols->physics_update_one;
    if (!strcmp(name, "game_monk_idle_anim")) return &symbols->idle_anim;
    if (!strcmp(name, "game_monk_walk_right_anim")) return &symbols->walk_right_anim;
    if (!strcmp(name, "_s_monk_0")) return &symbols->monk_0;
    if (!strcmp(name, "_s_monk_2")) return &symbols->monk_2;
    if (!strcmp(name, "sys_state_flags")) return &symbols->state_flags;
    if (!strcmp(name, "sys_state_counters")) return &symbols->state_counters;
    if (!strcmp(name, "sys_state_init")) return &symbols->state_init;
    if (!strcmp(name, "sys_state_set_flag")) return &symbols->state_set_flag;
    if (!strcmp(name, "sys_state_clear_flag")) return &symbols->state_clear_flag;
    if (!strcmp(name, "sys_state_test_flag")) return &symbols->state_test_flag;
    if (!strcmp(name, "sys_state_get_counter")) return &symbols->state_get_counter;
    if (!strcmp(name, "sys_state_set_counter")) return &symbols->state_set_counter;
    if (!strcmp(name, "sys_state_add_counter")) return &symbols->state_add_counter;
    if (!strcmp(name, "sys_state_sub_counter")) return &symbols->state_sub_counter;
    if (!strcmp(name, "sys_inventory_count")) return &symbols->inventory_count;
    if (!strcmp(name, "sys_inventory_items")) return &symbols->inventory_items;
    if (!strcmp(name, "sys_inventory_init")) return &symbols->inventory_init;
    if (!strcmp(name, "sys_inventory_add")) return &symbols->inventory_add;
    if (!strcmp(name, "sys_inventory_remove")) return &symbols->inventory_remove;
    if (!strcmp(name, "sys_inventory_contains")) return &symbols->inventory_contains;
    if (!strcmp(name, "sys_inventory_get")) return &symbols->inventory_get;
    if (!strcmp(name, "sys_interaction_init")) return &symbols->interaction_init;
    if (!strcmp(name, "sys_interaction_set_filter")) return &symbols->interaction_set_filter;
    if (!strcmp(name, "sys_interaction_set_handler")) return &symbols->interaction_set_handler;
    if (!strcmp(name, "sys_interaction_find")) return &symbols->interaction_find;
    if (!strcmp(name, "sys_interaction_try")) return &symbols->interaction_try;
    if (!strcmp(name, "sys_script_pc")) return &symbols->script_pc;
    if (!strcmp(name, "sys_script_ops_left")) return &symbols->script_ops_left;
    if (!strcmp(name, "sys_script_init")) return &symbols->script_init;
    if (!strcmp(name, "sys_script_start")) return &symbols->script_start;
    if (!strcmp(name, "sys_script_update")) return &symbols->script_update;
    if (!strcmp(name, "sys_script_is_running")) return &symbols->script_is_running;
    if (!strcmp(name, "sys_mem_is_128k")) return &symbols->mem_is_128k;
    if (!strcmp(name, "sys_mem_detect")) return &symbols->mem_detect;
    if (!strcmp(name, "sys_mem_copy_from_bank")) return &symbols->mem_copy_from_bank;
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
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regBC, ((uint16_t)x << 8) | y);
    z80ex_set_reg(machine->cpu, regDE, ((uint16_t)room << 8) | speed);
    return run_routine(machine, routine);
}

static int call_array_index(struct Machine *machine, uint16_t routine,
                            uint16_t array, uint8_t index, uint16_t *result) {
    int carry;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, array);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)index << 8);
    carry = run_routine(machine, routine);
    if (result) *result = z80ex_get_reg(machine->cpu, regHL);
    return carry;
}

static void configure_array(struct Machine *machine, uint16_t address,
                            uint8_t capacity, uint8_t component_size,
                            uint8_t count) {
    size_t bytes = ARRAY_DATA + capacity * component_size;
    memset(machine->memory + address, 0, bytes);
    machine->memory[address + ARRAY_COUNT] = count;
    machine->memory[address + ARRAY_MAX_COUNT] = capacity;
    machine->memory[address + ARRAY_COMPONENT_SIZE] = component_size;
    set_word(machine->memory, address + ARRAY_PEND,
             address + ARRAY_DATA + count * component_size);
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
    z80ex_set_reg(machine->cpu, regHL, machine->symbols.tile_solid_table);
    run_routine(machine, machine->symbols.map_set_collision_table);
    z80ex_reset(machine->cpu);
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
           machine->memory[entity + E_CMPS] == 0x40 &&
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

static void test_array_contract(struct Machine *machine) {
    uint8_t *source;
    uint8_t *destination;
    uint16_t result;
    int carry;

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 2);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    source[0] = 7;
    carry = call_array_index(machine, machine->symbols.array_init,
                             TEST_ARRAY_SOURCE, 0, NULL);
    report("array initialization resets runtime state only",
           !carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 0 &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_MAX_COUNT] == 3 &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COMPONENT_SIZE] == 3 &&
           get_word(machine->memory, TEST_ARRAY_SOURCE + ARRAY_PEND) ==
               TEST_ARRAY_SOURCE + ARRAY_DATA && source[0] == 0);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 2);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    source[0] = 1; source[1] = 10; source[2] = 11;
    source[3] = 2; source[4] = 20; source[5] = 21;
    carry = call_array_index(machine, machine->symbols.array_get,
                             TEST_ARRAY_SOURCE, 1, &result);
    report("array lookup returns the requested element",
           !carry && result == TEST_ARRAY_SOURCE + ARRAY_DATA + 3);
    carry = call_array_index(machine, machine->symbols.array_get,
                             TEST_ARRAY_SOURCE, 2, &result);
    report("array lookup rejects an index equal to count",
           carry && result == 0);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 3);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    source[0] = 1; source[1] = 10; source[2] = 11;
    source[3] = 2; source[4] = 20; source[5] = 21;
    source[6] = 3; source[7] = 30; source[8] = 31;
    carry = call_array_index(machine, machine->symbols.array_remove,
                             TEST_ARRAY_SOURCE, 1, NULL);
    report("array removal compacts following elements",
           !carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 2 &&
           get_word(machine->memory, TEST_ARRAY_SOURCE + ARRAY_PEND) ==
               TEST_ARRAY_SOURCE + ARRAY_DATA + 6 &&
           source[3] == 3 && source[4] == 30 && source[5] == 31 &&
           source[6] == 0);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 1);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    source[0] = 7; source[1] = 70; source[2] = 71;
    carry = call_array_index(machine, machine->symbols.array_remove,
                             TEST_ARRAY_SOURCE, 1, NULL);
    report("array removal rejects invalid indices without mutation",
           carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 1 &&
           source[0] == 7 && source[1] == 70 && source[2] == 71);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 2);
    configure_array(machine, TEST_ARRAY_DESTINATION, 2, 3, 1);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    destination = machine->memory + TEST_ARRAY_DESTINATION + ARRAY_DATA;
    source[0] = 1; source[1] = 10; source[2] = 11;
    source[3] = 2; source[4] = 20; source[5] = 21;
    destination[0] = 9; destination[1] = 90; destination[2] = 91;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regHL, TEST_ARRAY_SOURCE);
    z80ex_set_reg(machine->cpu, regDE, TEST_ARRAY_DESTINATION);
    carry = run_routine(machine, machine->symbols.array_move_all);
    report("array move preserves elements that do not fit",
           carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 1 &&
           source[0] == 2 && source[1] == 20 && source[2] == 21 &&
           machine->memory[TEST_ARRAY_DESTINATION + ARRAY_COUNT] == 2 &&
           destination[3] == 1 && destination[4] == 10 && destination[5] == 11);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 3, 3, 2);
    configure_array(machine, TEST_ARRAY_DESTINATION, 3, 3, 0);
    source = machine->memory + TEST_ARRAY_SOURCE + ARRAY_DATA;
    destination = machine->memory + TEST_ARRAY_DESTINATION + ARRAY_DATA;
    source[0] = 0; source[1] = 40; source[2] = 41;
    source[3] = 5; source[4] = 50; source[5] = 51;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regHL, TEST_ARRAY_SOURCE);
    z80ex_set_reg(machine->cpu, regDE, TEST_ARRAY_DESTINATION);
    carry = run_routine(machine, machine->symbols.array_move_all);
    report("array move transfers every element when capacity is available",
           !carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 0 &&
           machine->memory[TEST_ARRAY_DESTINATION + ARRAY_COUNT] == 2 &&
           destination[0] == 0 && destination[1] == 40 && destination[2] == 41 &&
           destination[3] == 5 && destination[4] == 50 && destination[5] == 51);

    reset_fixture(machine);
    configure_array(machine, TEST_ARRAY_SOURCE, 2, 3, 1);
    configure_array(machine, TEST_ARRAY_DESTINATION, 2, 2, 0);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regHL, TEST_ARRAY_SOURCE);
    z80ex_set_reg(machine->cpu, regDE, TEST_ARRAY_DESTINATION);
    carry = run_routine(machine, machine->symbols.array_move_all);
    report("array move rejects incompatible component sizes",
           carry &&
           machine->memory[TEST_ARRAY_SOURCE + ARRAY_COUNT] == 1 &&
           machine->memory[TEST_ARRAY_DESTINATION + ARRAY_COUNT] == 0);
}

static void prepare_collision_entities(struct Machine *machine) {
    memset(machine->memory + TEST_COLLIDER, 0, ENTITY_SIZE);
    memset(machine->memory + TEST_COLLISIONABLE, 0, ENTITY_SIZE);
    machine->memory[TEST_COLLIDER + E_CMPS] = 1;
    machine->memory[TEST_COLLIDER + E_STATUS] = STATUS_PLAYER_BULLET;
    machine->memory[TEST_COLLISIONABLE + E_CMPS] = 1;
    machine->memory[TEST_COLLISIONABLE + E_STATUS] = 3; /* STATUS_ENEMY */
}

static void test_collision_handler_contract(struct Machine *machine) {
    reset_fixture(machine);
    prepare_collision_entities(machine);
    run_routine(machine, machine->symbols.collision_init);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, TEST_COLLIDER);
    z80ex_set_reg(machine->cpu, regIY, TEST_COLLISIONABLE);
    run_routine(machine, machine->symbols.collision_on_hit);
    report("the engine collision handler defaults to no action",
           machine->memory[TEST_COLLIDER + E_CMPS] == 1 &&
           machine->memory[TEST_COLLISIONABLE + E_CMPS] == 1);

    reset_fixture(machine);
    prepare_collision_entities(machine);
    run_routine(machine, machine->symbols.game_collision_init);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, TEST_COLLIDER);
    z80ex_set_reg(machine->cpu, regIY, TEST_COLLISIONABLE);
    run_routine(machine, machine->symbols.collision_on_hit);
    report("a registered game collision handler applies game rules",
           machine->memory[TEST_COLLIDER + E_CMPS] == 0 &&
           machine->memory[TEST_COLLISIONABLE + E_CMPS] == 0 &&
           z80ex_get_reg(machine->cpu, regIX) == TEST_COLLIDER &&
           z80ex_get_reg(machine->cpu, regIY) == TEST_COLLISIONABLE);
}

static void prepare_behavior_entity(struct Machine *machine) {
    memset(machine->memory + TEST_BEHAVIOR_ENTITY, 0, ENTITY_SIZE);
    machine->memory[machine->symbols.current_room] = 0;
    set_word(machine->memory, TEST_BEHAVIOR_ENTITY + E_BEH, TEST_BEHAVIOR);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, TEST_BEHAVIOR_ENTITY);
}

static void test_behavior_contract(struct Machine *machine) {
    reset_fixture(machine);
    prepare_behavior_entity(machine);
    set_word(machine->memory, TEST_BEHAVIOR, machine->symbols.beh_action_set_vx);
    machine->memory[TEST_BEHAVIOR + 2] = 7;
    set_word(machine->memory, TEST_BEHAVIOR + 3, machine->symbols.beh_action_idle);
    set_word(machine->memory, TEST_BEHAVIOR + 5, 0); /* CONDITIONS_END */
    run_routine(machine, machine->symbols.beh_update_one);
    report("behavior bytecode dispatches action callbacks",
           machine->memory[TEST_BEHAVIOR_ENTITY + E_SPEED_X] == 7 &&
           get_word(machine->memory, TEST_BEHAVIOR_ENTITY + E_BEH) ==
               TEST_BEHAVIOR + 3);

    reset_fixture(machine);
    prepare_behavior_entity(machine);
    set_word(machine->memory, TEST_BEHAVIOR, machine->symbols.beh_action_idle);
    set_word(machine->memory, TEST_BEHAVIOR + 2, machine->symbols.beh_cond_true);
    set_word(machine->memory, TEST_BEHAVIOR + 4, TEST_BEHAVIOR);
    run_routine(machine, machine->symbols.beh_update_one);
    report("behavior dispatch budget yields an immediate action cycle",
           get_word(machine->memory, TEST_BEHAVIOR_ENTITY + E_BEH) == TEST_BEHAVIOR &&
           machine->memory[machine->symbols.beh_actions_left] == 0);
}

static uint16_t create_behavior_enemy_fixture(struct Machine *machine,
                                              uint16_t factory,
                                              uint8_t player_x,
                                              uint8_t enemy_x,
                                              uint8_t enemy_y) {
    uint16_t player = machine->symbols.entity_array;
    uint16_t enemy = player + ENTITY_SIZE;
    reset_fixture(machine);
    machine->memory[machine->symbols.current_room] = 0;
    if (call_factory(machine, machine->symbols.create_player, 0, 0, 0, 0))
        die("test player creation failed", NULL);
    machine->memory[player + E_X] = player_x;
    if (call_factory(machine, factory, enemy_x, enemy_y, 0, 0))
        die("test behavior enemy creation failed", NULL);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, enemy);
    run_routine(machine, machine->symbols.beh_update_one);
    return enemy;
}

static void test_game_enemy_behaviors(struct Machine *machine) {
    uint16_t enemy;

    enemy = create_behavior_enemy_fixture(machine,
                                           machine->symbols.create_chaser_enemy,
                                           10, 40, 24);
    report("a chasing enemy moves toward a player on its left",
           machine->memory[enemy + E_SPEED_X] == 0xff &&
           machine->memory[enemy + E_CMPS] == 0x5b);

    enemy = create_behavior_enemy_fixture(machine,
                                           machine->symbols.create_chaser_enemy,
                                           50, 20, 24);
    report("a chasing enemy moves toward a player on its right",
           machine->memory[enemy + E_SPEED_X] == 1);

    enemy = create_behavior_enemy_fixture(machine,
                                           machine->symbols.create_position_patrol_enemy,
                                           10, 48, 24);
    report("a position patrol reverses at its configured right limit",
           machine->memory[enemy + E_SPEED_X] == 0xff &&
           machine->memory[enemy + E_SPEED_X + 1] == 1);

    enemy = create_behavior_enemy_fixture(machine,
                                           machine->symbols.create_flying_enemy,
                                           10, 30, 24);
    report("a flying enemy moves without the gravity component",
           machine->memory[enemy + E_Y] == 25 &&
           machine->memory[enemy + E_SPEED_Y] == 1 &&
           machine->memory[enemy + E_ON_AIR] == 1 &&
           machine->memory[enemy + E_CMPS] == 0x59);
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

static uint16_t prepare_physics_entity(struct Machine *machine) {
    uint16_t entity = machine->symbols.entity_array;
    reset_fixture(machine);
    z80ex_set_reg(machine->cpu, regHL, machine->symbols.tile_solid_table);
    run_routine(machine, machine->symbols.map_set_collision_table);
    memset(machine->memory + TEST_MAP_ADDRESS, 0, MAP_WIDTH * MAP_HEIGHT);
    set_word(machine->memory, machine->symbols.current_map_data, TEST_MAP_ADDRESS);
    machine->memory[machine->symbols.current_room] = 0;
    memset(machine->memory + entity, 0, ENTITY_SIZE);
    machine->memory[entity + E_X] = 10;
    machine->memory[entity + E_Y] = 20;
    machine->memory[entity + E_WIDTH] = 5;
    machine->memory[entity + E_HEIGHT] = 16;
    machine->memory[entity + E_ROOM] = 0;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, entity);
    return entity;
}

static void test_physics_contract(struct Machine *machine) {
    uint16_t entity;

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_ON_AIR] = 1;
    run_routine(machine, machine->symbols.physics_update_one);
    report("gravity accelerates an airborne entity",
           machine->memory[entity + E_SPEED_Y] == 1 &&
           machine->memory[entity + E_Y] == 21 &&
           machine->memory[entity + E_MOVED] == 1);

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_ON_AIR] = 1;
    machine->memory[entity + E_SPEED_Y] = 8;
    run_routine(machine, machine->symbols.physics_update_one);
    report("falling speed is capped at terminal velocity",
           machine->memory[entity + E_SPEED_Y] == 8 &&
           machine->memory[entity + E_Y] == 28);

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_CMPS] = 0x04; /* c_cmp_input */
    machine->memory[entity + E_SPEED_X] = 2;
    run_routine(machine, machine->symbols.physics_update_one);
    report("configured input friction reduces horizontal speed",
           machine->memory[entity + E_SPEED_X] == 1 &&
           machine->memory[entity + E_X] == 11);

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_X] = 60;
    machine->memory[entity + E_SPEED_X] = 2;
    run_routine(machine, machine->symbols.physics_update_one);
    report("physics clamps entities to the right world edge",
           machine->memory[entity + E_X] == 59 &&
           machine->memory[entity + E_SPEED_X] == 0);

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_Y] = 140;
    machine->memory[entity + E_ON_AIR] = 1;
    machine->memory[entity + E_SPEED_Y] = 4;
    run_routine(machine, machine->symbols.physics_update_one);
    report("falling entities land on the world floor",
           machine->memory[entity + E_Y] == 144 &&
           machine->memory[entity + E_SPEED_Y] == 0 &&
           machine->memory[entity + E_ON_AIR] == 0);

    entity = prepare_physics_entity(machine);
    machine->memory[entity + E_Y] = 2;
    machine->memory[entity + E_ON_AIR] = 1;
    machine->memory[entity + E_SPEED_Y] = 0xfc; /* -4 */
    run_routine(machine, machine->symbols.physics_update_one);
    report("rising entities are clamped to the world ceiling",
           machine->memory[entity + E_Y] == 0 &&
           machine->memory[entity + E_SPEED_Y] == 0);

    entity = prepare_physics_entity(machine);
    machine->memory[TEST_MAP_ADDRESS + 4 * MAP_WIDTH + 2] = 2;
    machine->memory[entity + E_Y] = 15;
    machine->memory[entity + E_ON_AIR] = 1;
    machine->memory[entity + E_SPEED_Y] = 1;
    run_routine(machine, machine->symbols.physics_update_one);
    report("falling entities land on solid map tiles",
           machine->memory[entity + E_Y] == 16 &&
           machine->memory[entity + E_SPEED_Y] == 0 &&
           machine->memory[entity + E_ON_AIR] == 0);

    entity = prepare_physics_entity(machine);
    machine->memory[TEST_MAP_ADDRESS + 4 * MAP_WIDTH + 2] = 2;
    machine->memory[entity + E_Y] = 34;
    machine->memory[entity + E_ON_AIR] = 1;
    machine->memory[entity + E_SPEED_Y] = 0xfd; /* -3 */
    run_routine(machine, machine->symbols.physics_update_one);
    report("rising entities stop below solid map tiles",
           machine->memory[entity + E_Y] == 40 &&
           machine->memory[entity + E_SPEED_Y] == 0);
}

static uint8_t call_state_value(struct Machine *machine, uint16_t routine,
                                uint8_t id, uint8_t value) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)id << 8);
    z80ex_set_reg(machine->cpu, regBC, (uint16_t)value << 8);
    run_routine(machine, routine);
    return z80ex_get_reg(machine->cpu, regAF) >> 8;
}

static void test_state_contract(struct Machine *machine) {
    uint16_t af;

    reset_fixture(machine);
    memset(machine->memory + machine->symbols.state_flags, 0xff, 32);
    memset(machine->memory + machine->symbols.state_counters, 0xff, 32);
    run_routine(machine, machine->symbols.state_init);
    report("state initialization clears flags and counters",
           machine->memory[machine->symbols.state_flags] == 0 &&
           machine->memory[machine->symbols.state_flags + 31] == 0 &&
           machine->memory[machine->symbols.state_counters] == 0 &&
           machine->memory[machine->symbols.state_counters + 31] == 0);

    call_state_value(machine, machine->symbols.state_set_flag, 0, 0);
    call_state_value(machine, machine->symbols.state_set_flag, 255, 0);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)255 << 8);
    run_routine(machine, machine->symbols.state_test_flag);
    af = z80ex_get_reg(machine->cpu, regAF);
    report("flags cover the complete 0 to 255 id range",
           machine->memory[machine->symbols.state_flags] == 0x01 &&
           machine->memory[machine->symbols.state_flags + 31] == 0x80 &&
           (af & 0x40) != 0);

    call_state_value(machine, machine->symbols.state_clear_flag, 255, 0);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)255 << 8);
    run_routine(machine, machine->symbols.state_test_flag);
    af = z80ex_get_reg(machine->cpu, regAF);
    report("cleared flags use Z false for condition-friendly tests",
           machine->memory[machine->symbols.state_flags + 31] == 0 &&
           (af & 0x40) == 0);

    call_state_value(machine, machine->symbols.state_set_counter, 31, 250);
    report("counter values can be set and read",
           call_state_value(machine, machine->symbols.state_get_counter, 31, 0) == 250);

    report("counter addition saturates at 255",
           call_state_value(machine, machine->symbols.state_add_counter, 31, 10) == 255 &&
           machine->memory[machine->symbols.state_counters + 31] == 255);

    report("counter subtraction saturates at zero",
           call_state_value(machine, machine->symbols.state_sub_counter, 31, 255) == 0 &&
           machine->memory[machine->symbols.state_counters + 31] == 0);
}

static uint16_t call_inventory(struct Machine *machine, uint16_t routine,
                               uint8_t value) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)value << 8);
    run_routine(machine, routine);
    return z80ex_get_reg(machine->cpu, regAF);
}

static void test_inventory_contract(struct Machine *machine) {
    uint16_t af;
    int i;

    reset_fixture(machine);
    machine->memory[machine->symbols.inventory_count] = 8;
    memset(machine->memory + machine->symbols.inventory_items, 0xff, 8);
    call_inventory(machine, machine->symbols.inventory_init, 0);
    report("inventory initialization clears count and slots",
           machine->memory[machine->symbols.inventory_count] == 0 &&
           machine->memory[machine->symbols.inventory_items] == 0 &&
           machine->memory[machine->symbols.inventory_items + 7] == 0);

    af = call_inventory(machine, machine->symbols.inventory_add, 5);
    report("an item can be added to the inventory",
           (af & 1) == 0 &&
           machine->memory[machine->symbols.inventory_count] == 1 &&
           machine->memory[machine->symbols.inventory_items] == 5);

    af = call_inventory(machine, machine->symbols.inventory_add, 5);
    report("duplicate and empty item ids are rejected",
           (af & 1) != 0 &&
           (call_inventory(machine, machine->symbols.inventory_add, 0) & 1) != 0 &&
           machine->memory[machine->symbols.inventory_count] == 1);

    call_inventory(machine, machine->symbols.inventory_add, 9);
    af = call_inventory(machine, machine->symbols.inventory_contains, 9);
    report("inventory membership uses condition-friendly Z true",
           (af & 0x40) != 0);

    af = call_inventory(machine, machine->symbols.inventory_get, 1);
    report("inventory slots preserve insertion order",
           (af & 1) == 0 && (af >> 8) == 9);

    af = call_inventory(machine, machine->symbols.inventory_remove, 5);
    report("removing an item compacts following slots",
           (af & 1) == 0 &&
           machine->memory[machine->symbols.inventory_count] == 1 &&
           machine->memory[machine->symbols.inventory_items] == 9 &&
           machine->memory[machine->symbols.inventory_items + 1] == 0);

    af = call_inventory(machine, machine->symbols.inventory_remove, 9);
    report("removing the final item empties the inventory",
           (af & 1) == 0 &&
           machine->memory[machine->symbols.inventory_count] == 0 &&
           machine->memory[machine->symbols.inventory_items] == 0 &&
           (call_inventory(machine, machine->symbols.inventory_remove, 9) & 1) != 0);

    call_inventory(machine, machine->symbols.inventory_init, 0);
    for (i = 1; i <= 8; ++i)
        call_inventory(machine, machine->symbols.inventory_add, (uint8_t)i);
    af = call_inventory(machine, machine->symbols.inventory_add, 9);
    report("a full inventory rejects items without corruption",
           (af & 1) != 0 &&
           machine->memory[machine->symbols.inventory_count] == 8 &&
           machine->memory[machine->symbols.inventory_items + 7] == 8);

    af = call_inventory(machine, machine->symbols.inventory_get, 8);
    report("inventory lookup rejects an index equal to count",
           (af & 1) != 0 && (af >> 8) == 0);
}

static int call_interaction(struct Machine *machine, uint16_t routine,
                            uint16_t actor, uint8_t direction) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regIX, actor);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)direction << 8);
    return run_routine(machine, routine);
}

static void register_interaction_callback(struct Machine *machine,
                                          uint16_t setter, uint16_t callback) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regHL, callback);
    run_routine(machine, setter);
}

static void prepare_interaction(struct Machine *machine, uint8_t candidate_x,
                                uint8_t candidate_room, int reject_filter) {
    uint16_t actor = machine->symbols.entity_array;
    uint16_t candidate = actor + ENTITY_SIZE;

    reset_fixture(machine);
    memset(machine->memory + actor, 0, ENTITY_SIZE * 2);
    machine->memory[machine->symbols.entities + ARRAY_COUNT] = 2;
    machine->memory[actor + E_CMPS] = 0x04;
    machine->memory[actor + E_X] = 10;
    machine->memory[actor + E_Y] = 20;
    machine->memory[actor + E_WIDTH] = 4;
    machine->memory[actor + E_HEIGHT] = 16;
    machine->memory[actor + E_ROOM] = 0;
    machine->memory[candidate + E_CMPS] = 0x40;
    machine->memory[candidate + E_X] = candidate_x;
    machine->memory[candidate + E_Y] = 20;
    machine->memory[candidate + E_WIDTH] = 2;
    machine->memory[candidate + E_HEIGHT] = 8;
    machine->memory[candidate + E_ROOM] = candidate_room;

    /* Handler: marker = 0xa5; ret. */
    machine->memory[TEST_INTERACTION_HANDLER] = 0x3e;
    machine->memory[TEST_INTERACTION_HANDLER + 1] = 0xa5;
    machine->memory[TEST_INTERACTION_HANDLER + 2] = 0x32;
    machine->memory[TEST_INTERACTION_HANDLER + 3] = TEST_INTERACTION_MARKER & 0xff;
    machine->memory[TEST_INTERACTION_HANDLER + 4] = TEST_INTERACTION_MARKER >> 8;
    machine->memory[TEST_INTERACTION_HANDLER + 5] = 0xc9;
    /* Reject filter: A=1, Z=0; ret. */
    machine->memory[TEST_INTERACTION_FILTER] = 0x3e;
    machine->memory[TEST_INTERACTION_FILTER + 1] = 0x01;
    machine->memory[TEST_INTERACTION_FILTER + 2] = 0xb7;
    machine->memory[TEST_INTERACTION_FILTER + 3] = 0xc9;

    call_interaction(machine, machine->symbols.interaction_init, actor, 0);
    register_interaction_callback(machine, machine->symbols.interaction_set_handler,
                                  TEST_INTERACTION_HANDLER);
    if (reject_filter)
        register_interaction_callback(machine, machine->symbols.interaction_set_filter,
                                      TEST_INTERACTION_FILTER);
}

static void test_interaction_contract(struct Machine *machine) {
    uint16_t actor = machine->symbols.entity_array;
    uint16_t candidate = actor + ENTITY_SIZE;
    int carry;

    prepare_interaction(machine, 14, 0, 0);
    carry = call_interaction(machine, machine->symbols.interaction_try, actor, 0);
    report("right-facing interaction dispatches the adjacent target",
           !carry && machine->memory[TEST_INTERACTION_MARKER] == 0xa5 &&
           z80ex_get_reg(machine->cpu, regIX) == actor &&
           z80ex_get_reg(machine->cpu, regIY) == candidate);

    prepare_interaction(machine, 8, 0, 0);
    carry = call_interaction(machine, machine->symbols.interaction_find, actor, 1);
    report("left-facing interaction finds the adjacent target",
           !carry && z80ex_get_reg(machine->cpu, regIY) == candidate &&
           machine->memory[TEST_INTERACTION_MARKER] == 0);

    prepare_interaction(machine, 17, 0, 0);
    carry = call_interaction(machine, machine->symbols.interaction_try, actor, 0);
    report("entities beyond interaction reach are ignored",
           carry && machine->memory[TEST_INTERACTION_MARKER] == 0);

    prepare_interaction(machine, 14, 1, 0);
    carry = call_interaction(machine, machine->symbols.interaction_try, actor, 0);
    report("interaction ignores entities in another room",
           carry && machine->memory[TEST_INTERACTION_MARKER] == 0);

    prepare_interaction(machine, 14, 0, 1);
    carry = call_interaction(machine, machine->symbols.interaction_try, actor, 0);
    report("the game filter can reject an interaction candidate",
           carry && machine->memory[TEST_INTERACTION_MARKER] == 0);
}

static uint16_t call_map_tile(struct Machine *machine, uint16_t routine,
                              uint8_t row, uint8_t column, uint8_t tile) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, (uint16_t)tile << 8);
    z80ex_set_reg(machine->cpu, regBC, ((uint16_t)row << 8) | column);
    run_routine(machine, routine);
    return z80ex_get_reg(machine->cpu, regAF);
}

static void prepare_dynamic_map(struct Machine *machine) {
    reset_fixture(machine);
    memset(machine->memory + TEST_MAP_ADDRESS, 0, MAP_WIDTH * MAP_HEIGHT);
    z80ex_set_reg(machine->cpu, regHL, machine->symbols.tileset);
    z80ex_set_reg(machine->cpu, regDE, TEST_MAP_ADDRESS);
    z80ex_set_reg(machine->cpu, regIX, machine->symbols.tile_solid_table);
    run_routine(machine, machine->symbols.map_init);
}

static void test_dynamic_map_contract(struct Machine *machine) {
    enum { FRONT_TILE_0 = 0xc000 + 80 * 2 + 8 };
    uint16_t af;
    uint8_t expected;

    prepare_dynamic_map(machine);
    af = call_map_tile(machine, machine->symbols.map_set_tile, 3, 5, 7);
    report("a map tile can be changed and read back",
           (af & 1) == 0 &&
           machine->memory[TEST_MAP_ADDRESS + 3 * MAP_WIDTH + 5] == 7 &&
           (call_map_tile(machine, machine->symbols.map_get_tile, 3, 5, 0) >> 8) == 7);

    af = call_map_tile(machine, machine->symbols.map_set_tile, MAP_HEIGHT, 0, 9);
    report("dynamic map access rejects out-of-bounds coordinates",
           (af & 1) != 0 &&
           (call_map_tile(machine, machine->symbols.map_get_tile, 0, MAP_WIDTH, 0) & 1) != 0);

    call_map_tile(machine, machine->symbols.map_set_tile, 3, 5, 2);
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regBC, ((uint16_t)(3 * 8) << 8) | (5 * 4));
    run_routine(machine, machine->symbols.map_is_solid);
    report("tile changes immediately affect map collision queries",
           (z80ex_get_reg(machine->cpu, regAF) & 0x40) == 0);

    expected = machine->memory[machine->symbols.tileset + 32];
    machine->memory[FRONT_TILE_0] = expected ^ 0xff;
    af = call_map_tile(machine, machine->symbols.map_set_tile_and_redraw, 0, 0, 1);
    report("a changed tile can be redrawn without drawing the full map",
           (af & 1) == 0 &&
           machine->memory[TEST_MAP_ADDRESS] == 1 &&
           machine->memory[FRONT_TILE_0] == expected);
}

static void run_script(struct Machine *machine, uint16_t address) {
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regHL, address);
    run_routine(machine, machine->symbols.script_start);
    z80ex_reset(machine->cpu);
    run_routine(machine, machine->symbols.script_update);
}

static void test_script_contract(struct Machine *machine) {
    enum {
        OP_END = 0, OP_SET_FLAG = 1, OP_REQUIRE_FLAG = 3,
        OP_ADD_ITEM = 4, OP_REMOVE_ITEM = 5, OP_REQUIRE_ITEM = 6,
        OP_SET_COUNTER = 7, OP_ADD_COUNTER = 8, OP_REQUIRE_COUNTER = 9,
        OP_SET_TILE = 10, OP_CALL = 11, OP_GOTO = 12
    };
    uint16_t failure;
    uint16_t af;
    uint16_t p;

    reset_fixture(machine);
    call_state_value(machine, machine->symbols.state_init, 0, 0);
    p = TEST_SCRIPT;
    machine->memory[p++] = OP_SET_FLAG; machine->memory[p++] = 1;
    machine->memory[p++] = OP_SET_COUNTER; machine->memory[p++] = 2; machine->memory[p++] = 10;
    machine->memory[p++] = OP_ADD_COUNTER; machine->memory[p++] = 2; machine->memory[p++] = 5;
    machine->memory[p++] = OP_END;
    run_script(machine, TEST_SCRIPT);
    report("event scripts apply flag and counter actions",
           (machine->memory[machine->symbols.state_flags] & 0x02) != 0 &&
           machine->memory[machine->symbols.state_counters + 2] == 15 &&
           get_word(machine->memory, machine->symbols.script_pc) == 0);

    reset_fixture(machine);
    call_state_value(machine, machine->symbols.state_init, 0, 0);
    failure = TEST_SCRIPT + 8;
    p = TEST_SCRIPT;
    machine->memory[p++] = OP_REQUIRE_FLAG; machine->memory[p++] = 7;
    set_word(machine->memory, p, failure); p += 2;
    machine->memory[p++] = OP_SET_COUNTER; machine->memory[p++] = 0; machine->memory[p++] = 1;
    machine->memory[p++] = OP_END;
    machine->memory[p++] = OP_SET_COUNTER; machine->memory[p++] = 0; machine->memory[p++] = 2;
    machine->memory[p++] = OP_END;
    run_script(machine, TEST_SCRIPT);
    report("a failed flag requirement branches to its target",
           machine->memory[machine->symbols.state_counters] == 2);

    call_state_value(machine, machine->symbols.state_set_flag, 7, 0);
    run_script(machine, TEST_SCRIPT);
    report("a satisfied flag requirement continues in sequence",
           machine->memory[machine->symbols.state_counters] == 1);

    reset_fixture(machine);
    call_state_value(machine, machine->symbols.state_init, 0, 0);
    call_inventory(machine, machine->symbols.inventory_init, 0);
    failure = TEST_SCRIPT + 13;
    p = TEST_SCRIPT;
    machine->memory[p++] = OP_ADD_ITEM; machine->memory[p++] = 4;
    set_word(machine->memory, p, failure); p += 2;
    machine->memory[p++] = OP_REQUIRE_ITEM; machine->memory[p++] = 4;
    set_word(machine->memory, p, failure); p += 2;
    machine->memory[p++] = OP_REMOVE_ITEM; machine->memory[p++] = 4;
    set_word(machine->memory, p, failure); p += 2;
    machine->memory[p++] = OP_END;
    machine->memory[p++] = OP_SET_FLAG; machine->memory[p++] = 9;
    machine->memory[p++] = OP_END;
    run_script(machine, TEST_SCRIPT);
    report("event scripts compose inventory actions and conditions",
           machine->memory[machine->symbols.inventory_count] == 0 &&
           (machine->memory[machine->symbols.state_flags + 1] & 0x02) == 0);

    call_state_value(machine, machine->symbols.state_set_counter, 3, 4);
    failure = TEST_SCRIPT + 8;
    p = TEST_SCRIPT;
    machine->memory[p++] = OP_REQUIRE_COUNTER; machine->memory[p++] = 3;
    machine->memory[p++] = 5; set_word(machine->memory, p, failure); p += 2;
    machine->memory[p++] = OP_SET_FLAG; machine->memory[p++] = 10;
    machine->memory[p++] = OP_END;
    machine->memory[p++] = OP_SET_FLAG; machine->memory[p++] = 11;
    machine->memory[p++] = OP_END;
    run_script(machine, TEST_SCRIPT);
    report("counter requirements branch below their minimum",
           (machine->memory[machine->symbols.state_flags + 1] & 0x08) != 0 &&
           (machine->memory[machine->symbols.state_flags + 1] & 0x04) == 0);

    prepare_dynamic_map(machine);
    machine->memory[TEST_SCRIPT_CALLBACK] = 0x3e;
    machine->memory[TEST_SCRIPT_CALLBACK + 1] = 0x5a;
    machine->memory[TEST_SCRIPT_CALLBACK + 2] = 0x32;
    machine->memory[TEST_SCRIPT_CALLBACK + 3] = TEST_SCRIPT_MARKER & 0xff;
    machine->memory[TEST_SCRIPT_CALLBACK + 4] = TEST_SCRIPT_MARKER >> 8;
    machine->memory[TEST_SCRIPT_CALLBACK + 5] = 0xc9;
    p = TEST_SCRIPT;
    machine->memory[p++] = OP_SET_TILE; machine->memory[p++] = 0;
    machine->memory[p++] = 0; machine->memory[p++] = 1;
    machine->memory[p++] = OP_CALL; set_word(machine->memory, p, TEST_SCRIPT_CALLBACK); p += 2;
    machine->memory[p++] = OP_END;
    run_script(machine, TEST_SCRIPT);
    report("event scripts update tiles and invoke game callbacks",
           machine->memory[TEST_MAP_ADDRESS] == 1 &&
           machine->memory[TEST_SCRIPT_MARKER] == 0x5a);

    reset_fixture(machine);
    machine->memory[TEST_SCRIPT] = OP_GOTO;
    set_word(machine->memory, TEST_SCRIPT + 1, TEST_SCRIPT);
    run_script(machine, TEST_SCRIPT);
    af = call_state_value(machine, machine->symbols.script_is_running, 0, 0);
    report("the script budget yields immediate instruction loops",
           get_word(machine->memory, machine->symbols.script_pc) == TEST_SCRIPT &&
           machine->memory[machine->symbols.script_ops_left] == 0 &&
           af == 0);
}

static void test_memory_capacity_contract(struct Machine *machine) {
    uint16_t af;
    int carry;

    /* The test host models one flat 64K address space and ignores Gate Array
       writes, so the detector must select the 64K path. */
    reset_fixture(machine);
    machine->memory[machine->symbols.mem_is_128k + 1] = 0xa7;
    carry = run_routine(machine, machine->symbols.mem_detect);
    af = z80ex_get_reg(machine->cpu, regAF);
    report("memory detection reports the emulated 64K machine",
           !carry && (af >> 8) == 0 && (af & 0x40) != 0 &&
           machine->memory[machine->symbols.mem_is_128k] == 0 &&
           machine->memory[machine->symbols.mem_is_128k + 1] == 0xa7);

    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, 0);          /* bank 0 */
    z80ex_set_reg(machine->cpu, regHL, 0x4000);
    z80ex_set_reg(machine->cpu, regDE, TEST_SCRIPT_MARKER);
    z80ex_set_reg(machine->cpu, regBC, 1);
    report("bank copies fail safely on a 64K machine",
           run_routine(machine, machine->symbols.mem_copy_from_bank));

    machine->memory[machine->symbols.mem_is_128k] = 1;
    z80ex_reset(machine->cpu);
    z80ex_set_reg(machine->cpu, regAF, 4u << 8);    /* first invalid bank */
    z80ex_set_reg(machine->cpu, regHL, 0x4000);
    z80ex_set_reg(machine->cpu, regDE, TEST_SCRIPT_MARKER);
    z80ex_set_reg(machine->cpu, regBC, 1);
    report("bank copies reject bank ids outside zero to three",
           run_routine(machine, machine->symbols.mem_copy_from_bank));
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
    test_array_contract(&machine);
    test_collision_handler_contract(&machine);
    test_behavior_contract(&machine);
    test_game_enemy_behaviors(&machine);
    test_animation_set(&machine);
    test_physics_contract(&machine);
    test_state_contract(&machine);
    test_inventory_contract(&machine);
    test_interaction_contract(&machine);
    test_dynamic_map_contract(&machine);
    test_script_contract(&machine);
    test_memory_capacity_contract(&machine);
    printf("1..%d\n", tests_run);
    z80ex_destroy(machine.cpu);
    if (tests_failed) {
        fprintf(stderr, "%d of %d tests failed\n", tests_failed, tests_run);
        return EXIT_FAILURE;
    }
    printf("All %d Z80 engine tests passed.\n", tests_run);
    return EXIT_SUCCESS;
}
