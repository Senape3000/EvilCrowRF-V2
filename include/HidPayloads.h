/**
 * @file HidPayloads.h
 * @brief HID keystroke definitions and ASCII-to-HID conversion table.
 *
 * Used by MouseJack for injecting keystrokes into vulnerable
 * wireless mice/keyboards (Microsoft and Logitech protocols).
 */

#ifndef HID_PAYLOADS_H
#define HID_PAYLOADS_H

#include <stdint.h>

// ── HID Modifier Keys ──────────────────────────────────────────
#define HID_MOD_NONE      0x00
#define HID_MOD_LCTRL     0x01
#define HID_MOD_LSHIFT    0x02
#define HID_MOD_LALT      0x04
#define HID_MOD_LGUI      0x08  // Windows/Command key
#define HID_MOD_RCTRL     0x10
#define HID_MOD_RSHIFT    0x20
#define HID_MOD_RALT      0x40
#define HID_MOD_RGUI      0x80

// ── HID Key Codes ───────────────────────────────────────────────
#define HID_KEY_NONE       0x00
#define HID_KEY_A          0x04
#define HID_KEY_B          0x05
#define HID_KEY_C          0x06
#define HID_KEY_D          0x07
#define HID_KEY_E          0x08
#define HID_KEY_F          0x09
#define HID_KEY_G          0x0A
#define HID_KEY_H          0x0B
#define HID_KEY_I          0x0C
#define HID_KEY_J          0x0D
#define HID_KEY_K          0x0E
#define HID_KEY_L          0x0F
#define HID_KEY_M          0x10
#define HID_KEY_N          0x11
#define HID_KEY_O          0x12
#define HID_KEY_P          0x13
#define HID_KEY_Q          0x14
#define HID_KEY_R          0x15
#define HID_KEY_S          0x16
#define HID_KEY_T          0x17
#define HID_KEY_U          0x18
#define HID_KEY_V          0x19
#define HID_KEY_W          0x1A
#define HID_KEY_X          0x1B
#define HID_KEY_Y          0x1C
#define HID_KEY_Z          0x1D
#define HID_KEY_1          0x1E
#define HID_KEY_2          0x1F
#define HID_KEY_3          0x20
#define HID_KEY_4          0x21
#define HID_KEY_5          0x22
#define HID_KEY_6          0x23
#define HID_KEY_7          0x24
#define HID_KEY_8          0x25
#define HID_KEY_9          0x26
#define HID_KEY_0          0x27
#define HID_KEY_ENTER      0x28
#define HID_KEY_ESCAPE     0x29
#define HID_KEY_BACKSPACE  0x2A
#define HID_KEY_TAB        0x2B
#define HID_KEY_SPACE      0x2C
#define HID_KEY_MINUS      0x2D
#define HID_KEY_EQUAL      0x2E
#define HID_KEY_LBRACKET   0x2F
#define HID_KEY_RBRACKET   0x30
#define HID_KEY_BACKSLASH  0x31
#define HID_KEY_SEMICOLON  0x33
#define HID_KEY_QUOTE      0x34
#define HID_KEY_GRAVE      0x35
#define HID_KEY_COMMA      0x36
#define HID_KEY_PERIOD     0x37
#define HID_KEY_SLASH      0x38
#define HID_KEY_CAPSLOCK   0x39
#define HID_KEY_F1         0x3A
#define HID_KEY_F2         0x3B
#define HID_KEY_F3         0x3C
#define HID_KEY_F4         0x3D
#define HID_KEY_F5         0x3E
#define HID_KEY_F6         0x3F
#define HID_KEY_F7         0x40
#define HID_KEY_F8         0x41
#define HID_KEY_F9         0x42
#define HID_KEY_F10        0x43
#define HID_KEY_F11        0x44
#define HID_KEY_F12        0x45
#define HID_KEY_DELETE     0x4C
#define HID_KEY_RIGHT      0x4F
#define HID_KEY_LEFT       0x50
#define HID_KEY_DOWN       0x51
#define HID_KEY_UP         0x52

// ── ASCII to HID Conversion ────────────────────────────────────
// Each entry: { modifier, keycode }
// Index = ASCII value (printable range 0x20-0x7E)
struct HidKeyEntry {
    uint8_t modifier;
    uint8_t keycode;
};

/**
 * Convert ASCII character to HID modifier + keycode.
 * @param ascii  Printable ASCII char (0x20-0x7E)
 * @param entry  Output HID key entry
 * @return true if character is mappable
 */
inline bool asciiToHid(char ascii, HidKeyEntry& entry) {
    // US keyboard layout mapping
    static const HidKeyEntry asciiMap[] = {
        // 0x20 ' '
        {HID_MOD_NONE,   HID_KEY_SPACE},
        // 0x21 '!'
        {HID_MOD_LSHIFT, HID_KEY_1},
        // 0x22 '"'
        {HID_MOD_LSHIFT, HID_KEY_QUOTE},
        // 0x23 '#'
        {HID_MOD_LSHIFT, HID_KEY_3},
        // 0x24 '$'
        {HID_MOD_LSHIFT, HID_KEY_4},
        // 0x25 '%'
        {HID_MOD_LSHIFT, HID_KEY_5},
        // 0x26 '&'
        {HID_MOD_LSHIFT, HID_KEY_7},
        // 0x27 '''
        {HID_MOD_NONE,   HID_KEY_QUOTE},
        // 0x28 '('
        {HID_MOD_LSHIFT, HID_KEY_9},
        // 0x29 ')'
        {HID_MOD_LSHIFT, HID_KEY_0},
        // 0x2A '*'
        {HID_MOD_LSHIFT, HID_KEY_8},
        // 0x2B '+'
        {HID_MOD_LSHIFT, HID_KEY_EQUAL},
        // 0x2C ','
        {HID_MOD_NONE,   HID_KEY_COMMA},
        // 0x2D '-'
        {HID_MOD_NONE,   HID_KEY_MINUS},
        // 0x2E '.'
        {HID_MOD_NONE,   HID_KEY_PERIOD},
        // 0x2F '/'
        {HID_MOD_NONE,   HID_KEY_SLASH},
        // 0x30-0x39: '0'-'9'
        {HID_MOD_NONE, HID_KEY_0}, {HID_MOD_NONE, HID_KEY_1},
        {HID_MOD_NONE, HID_KEY_2}, {HID_MOD_NONE, HID_KEY_3},
        {HID_MOD_NONE, HID_KEY_4}, {HID_MOD_NONE, HID_KEY_5},
        {HID_MOD_NONE, HID_KEY_6}, {HID_MOD_NONE, HID_KEY_7},
        {HID_MOD_NONE, HID_KEY_8}, {HID_MOD_NONE, HID_KEY_9},
        // 0x3A ':'
        {HID_MOD_LSHIFT, HID_KEY_SEMICOLON},
        // 0x3B ';'
        {HID_MOD_NONE,   HID_KEY_SEMICOLON},
        // 0x3C '<'
        {HID_MOD_LSHIFT, HID_KEY_COMMA},
        // 0x3D '='
        {HID_MOD_NONE,   HID_KEY_EQUAL},
        // 0x3E '>'
        {HID_MOD_LSHIFT, HID_KEY_PERIOD},
        // 0x3F '?'
        {HID_MOD_LSHIFT, HID_KEY_SLASH},
        // 0x40 '@'
        {HID_MOD_LSHIFT, HID_KEY_2},
        // 0x41-0x5A: 'A'-'Z'
        {HID_MOD_LSHIFT, HID_KEY_A}, {HID_MOD_LSHIFT, HID_KEY_B},
        {HID_MOD_LSHIFT, HID_KEY_C}, {HID_MOD_LSHIFT, HID_KEY_D},
        {HID_MOD_LSHIFT, HID_KEY_E}, {HID_MOD_LSHIFT, HID_KEY_F},
        {HID_MOD_LSHIFT, HID_KEY_G}, {HID_MOD_LSHIFT, HID_KEY_H},
        {HID_MOD_LSHIFT, HID_KEY_I}, {HID_MOD_LSHIFT, HID_KEY_J},
        {HID_MOD_LSHIFT, HID_KEY_K}, {HID_MOD_LSHIFT, HID_KEY_L},
        {HID_MOD_LSHIFT, HID_KEY_M}, {HID_MOD_LSHIFT, HID_KEY_N},
        {HID_MOD_LSHIFT, HID_KEY_O}, {HID_MOD_LSHIFT, HID_KEY_P},
        {HID_MOD_LSHIFT, HID_KEY_Q}, {HID_MOD_LSHIFT, HID_KEY_R},
        {HID_MOD_LSHIFT, HID_KEY_S}, {HID_MOD_LSHIFT, HID_KEY_T},
        {HID_MOD_LSHIFT, HID_KEY_U}, {HID_MOD_LSHIFT, HID_KEY_V},
        {HID_MOD_LSHIFT, HID_KEY_W}, {HID_MOD_LSHIFT, HID_KEY_X},
        {HID_MOD_LSHIFT, HID_KEY_Y}, {HID_MOD_LSHIFT, HID_KEY_Z},
        // 0x5B '['
        {HID_MOD_NONE, HID_KEY_LBRACKET},
        // 0x5C '\'
        {HID_MOD_NONE, HID_KEY_BACKSLASH},
        // 0x5D ']'
        {HID_MOD_NONE, HID_KEY_RBRACKET},
        // 0x5E '^'
        {HID_MOD_LSHIFT, HID_KEY_6},
        // 0x5F '_'
        {HID_MOD_LSHIFT, HID_KEY_MINUS},
        // 0x60 '`'
        {HID_MOD_NONE, HID_KEY_GRAVE},
        // 0x61-0x7A: 'a'-'z'
        {HID_MOD_NONE, HID_KEY_A}, {HID_MOD_NONE, HID_KEY_B},
        {HID_MOD_NONE, HID_KEY_C}, {HID_MOD_NONE, HID_KEY_D},
        {HID_MOD_NONE, HID_KEY_E}, {HID_MOD_NONE, HID_KEY_F},
        {HID_MOD_NONE, HID_KEY_G}, {HID_MOD_NONE, HID_KEY_H},
        {HID_MOD_NONE, HID_KEY_I}, {HID_MOD_NONE, HID_KEY_J},
        {HID_MOD_NONE, HID_KEY_K}, {HID_MOD_NONE, HID_KEY_L},
        {HID_MOD_NONE, HID_KEY_M}, {HID_MOD_NONE, HID_KEY_N},
        {HID_MOD_NONE, HID_KEY_O}, {HID_MOD_NONE, HID_KEY_P},
        {HID_MOD_NONE, HID_KEY_Q}, {HID_MOD_NONE, HID_KEY_R},
        {HID_MOD_NONE, HID_KEY_S}, {HID_MOD_NONE, HID_KEY_T},
        {HID_MOD_NONE, HID_KEY_U}, {HID_MOD_NONE, HID_KEY_V},
        {HID_MOD_NONE, HID_KEY_W}, {HID_MOD_NONE, HID_KEY_X},
        {HID_MOD_NONE, HID_KEY_Y}, {HID_MOD_NONE, HID_KEY_Z},
        // 0x7B '{'
        {HID_MOD_LSHIFT, HID_KEY_LBRACKET},
        // 0x7C '|'
        {HID_MOD_LSHIFT, HID_KEY_BACKSLASH},
        // 0x7D '}'
        {HID_MOD_LSHIFT, HID_KEY_RBRACKET},
        // 0x7E '~'
        {HID_MOD_LSHIFT, HID_KEY_GRAVE},
    };

    if (ascii < 0x20 || ascii > 0x7E) {
        entry.modifier = HID_MOD_NONE;
        entry.keycode  = HID_KEY_NONE;
        return false;
    }

    entry = asciiMap[ascii - 0x20];
    return true;
}

// ── DuckyScript Key Names ───────────────────────────────────────

struct DuckyKeyMapping {
    const char* name;
    uint8_t modifier;
    uint8_t keycode;
};

static const DuckyKeyMapping DUCKY_KEYS[] = {
    {"ENTER",      HID_MOD_NONE,  HID_KEY_ENTER},
    {"RETURN",     HID_MOD_NONE,  HID_KEY_ENTER},
    {"ESCAPE",     HID_MOD_NONE,  HID_KEY_ESCAPE},
    {"ESC",        HID_MOD_NONE,  HID_KEY_ESCAPE},
    {"BACKSPACE",  HID_MOD_NONE,  HID_KEY_BACKSPACE},
    {"TAB",        HID_MOD_NONE,  HID_KEY_TAB},
    {"SPACE",      HID_MOD_NONE,  HID_KEY_SPACE},
    {"CAPSLOCK",   HID_MOD_NONE,  HID_KEY_CAPSLOCK},
    {"DELETE",     HID_MOD_NONE,  HID_KEY_DELETE},
    {"DEL",        HID_MOD_NONE,  HID_KEY_DELETE},
    {"UP",         HID_MOD_NONE,  HID_KEY_UP},
    {"DOWN",       HID_MOD_NONE,  HID_KEY_DOWN},
    {"LEFT",       HID_MOD_NONE,  HID_KEY_LEFT},
    {"RIGHT",      HID_MOD_NONE,  HID_KEY_RIGHT},
    {"F1",         HID_MOD_NONE,  HID_KEY_F1},
    {"F2",         HID_MOD_NONE,  HID_KEY_F2},
    {"F3",         HID_MOD_NONE,  HID_KEY_F3},
    {"F4",         HID_MOD_NONE,  HID_KEY_F4},
    {"F5",         HID_MOD_NONE,  HID_KEY_F5},
    {"F6",         HID_MOD_NONE,  HID_KEY_F6},
    {"F7",         HID_MOD_NONE,  HID_KEY_F7},
    {"F8",         HID_MOD_NONE,  HID_KEY_F8},
    {"F9",         HID_MOD_NONE,  HID_KEY_F9},
    {"F10",        HID_MOD_NONE,  HID_KEY_F10},
    {"F11",        HID_MOD_NONE,  HID_KEY_F11},
    {"F12",        HID_MOD_NONE,  HID_KEY_F12},
    // Modifiers as standalone keys (for DuckyScript "GUI r" etc.)
    {"GUI",        HID_MOD_LGUI,  HID_KEY_NONE},
    {"WINDOWS",    HID_MOD_LGUI,  HID_KEY_NONE},
    {"CTRL",       HID_MOD_LCTRL, HID_KEY_NONE},
    {"CONTROL",    HID_MOD_LCTRL, HID_KEY_NONE},
    {"SHIFT",      HID_MOD_LSHIFT,HID_KEY_NONE},
    {"ALT",        HID_MOD_LALT,  HID_KEY_NONE},
    {nullptr, 0, 0}  // Sentinel
};

#endif // HID_PAYLOADS_H
