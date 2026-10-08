const types = @import("../types.zig");

pub const InputParamsStr = struct {
    default: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
    required: ?bool = null,
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    disabled: ?bool = null,
    include_capital: ?u32 = null,
    onInput: ?types.Callback = null,
};

pub const InputParamsEmail = struct {
    type: InputTypes = .email,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsPassword = struct {
    type: InputTypes = .password,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsTelephone = struct {
    type: InputTypes = .telephone,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsFloat = struct {
    type: InputTypes = .float,
    default: ?f32 = null,
    value: ?f32 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
};

pub const InputParamsInt = struct {
    type: InputTypes = .int,
    default: ?i32 = null,
    value: ?i32 = null,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
};

pub const InputParamsString = struct {
    type: InputTypes = .string,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
    min_len: ?u32 = null,
    max_len: ?u32 = null,
};

pub const InputParamsDate = struct {
    type: InputTypes = .date,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const InputParamsRadio = struct {
    type: InputTypes = .radio,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
    required: ?bool = null,
};

pub const InputParamsFile = struct {
    type: InputTypes = .file,
    // tag: ?[]const u8 = null,
    // required: ?bool = null,
    // disabled: ?bool = null,
    default_ptr: ?[*]const u8 = null,
    default_len: usize = 0,
    value_ptr: ?[*]const u8 = null,
    value_len: usize = 0,
};

pub const TextFieldConfig = struct {
    min: ?u32 = null,
    max: ?u32 = null,
};

pub const InputTypes = enum(u8) {
    int,
    float,
    string,
    checkbox,
    radio,
    password,
    email,
    file,
    telephone,
    date,
    none,
};

pub const TextFieldParams = union(enum) {
    string: InputParamsString,
    int: InputParamsInt,
    float: InputParamsFloat,
    // on_change: ?*const fn (event: *Event) void = null,
    // checkbox: InputParamsCheckBox,
    radio: InputParamsRadio,
    password: InputParamsPassword,
    email: InputParamsEmail,
    telephone: InputParamsTelephone,
    file: InputParamsFile,
    date: InputParamsDate,
};
