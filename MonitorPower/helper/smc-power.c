/*
 * smc-power: minimal privileged helper that toggles MacBook charging through
 * the System Management Controller (SMC).
 *
 * Usage (writes require root):
 *   smc-power status    print current charge-control state
 *   smc-power allow     MacBook charges from / draws power from USB-C
 *   smc-power inhibit   keep using USB-C power, but do not charge the battery
 *   smc-power block     ignore USB-C power entirely, run from battery
 *
 * Only these fixed verbs are accepted, so the binary can be safely whitelisted
 * in sudoers without letting callers write arbitrary SMC keys.
 *
 * SMC keys (Apple Silicon, same keys used by AlDente / batt):
 *   CHTE  (4 bytes) charge inhibit, firmware shipped with macOS 15.7+/26
 *   CH0B, CH0C (1 byte each) charge inhibit, older firmware
 *   CHIE  (1 byte)  adapter disable, newer firmware (0x08 = disabled)
 *   CH0I  (1 byte)  adapter disable, older firmware (0x01 = disabled)
 */

#include <IOKit/IOKitLib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_KEYINFO 9

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    UInt16 release;
} SMCKeyData_vers_t;

typedef struct {
    UInt16 version;
    UInt16 length;
    UInt32 cpuPLimit;
    UInt32 gpuPLimit;
    UInt32 memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef unsigned char SMCBytes_t[32];

typedef struct {
    UInt32 key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    UInt32 data32;
    SMCBytes_t bytes;
} SMCKeyData_t;

static io_connect_t conn;

static UInt32 key_code(const char *k) {
    return ((UInt32)k[0] << 24) | ((UInt32)k[1] << 16) | ((UInt32)k[2] << 8) | (UInt32)k[3];
}

static int smc_open(void) {
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!svc) {
        fprintf(stderr, "AppleSMC service not found\n");
        return -1;
    }
    kern_return_t kr = IOServiceOpen(svc, mach_task_self(), 0, &conn);
    IOObjectRelease(svc);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceOpen failed: 0x%x\n", kr);
        return -1;
    }
    return 0;
}

static kern_return_t smc_call(SMCKeyData_t *in, SMCKeyData_t *out) {
    size_t out_size = sizeof(SMCKeyData_t);
    return IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, in, sizeof(SMCKeyData_t), out, &out_size);
}

/* Returns the key's data size, or 0 if the key does not exist. */
static UInt32 smc_key_size(const char *key) {
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key_code(key);
    in.data8 = SMC_CMD_READ_KEYINFO;
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0)
        return 0;
    return out.keyInfo.dataSize;
}

static int smc_read(const char *key, unsigned char *buf, UInt32 *size) {
    UInt32 n = smc_key_size(key);
    if (n == 0 || n > sizeof(SMCBytes_t))
        return -1;
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key_code(key);
    in.keyInfo.dataSize = n;
    in.data8 = SMC_CMD_READ_BYTES;
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0)
        return -1;
    memcpy(buf, out.bytes, n);
    *size = n;
    return 0;
}

static int smc_write(const char *key, const unsigned char *buf, UInt32 n) {
    UInt32 expected = smc_key_size(key);
    if (expected == 0 || expected != n) {
        fprintf(stderr, "SMC key %s missing or size mismatch (%u != %u)\n", key, expected, n);
        return -1;
    }
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key_code(key);
    in.keyInfo.dataSize = n;
    in.data8 = SMC_CMD_WRITE_BYTES;
    memcpy(in.bytes, buf, n);
    kern_return_t kr = smc_call(&in, &out);
    if (kr != KERN_SUCCESS || out.result != 0) {
        fprintf(stderr, "SMC write %s failed (kr=0x%x, result=%d)\n", key, kr, out.result);
        return -1;
    }
    return 0;
}

static int set_charging(int enabled) {
    if (smc_key_size("CHTE") == 4) {
        unsigned char v[4] = {enabled ? 0x00 : 0x01, 0x00, 0x00, 0x00};
        return smc_write("CHTE", v, 4);
    }
    if (smc_key_size("CH0B") == 1 && smc_key_size("CH0C") == 1) {
        unsigned char v = enabled ? 0x00 : 0x02;
        if (smc_write("CH0B", &v, 1) != 0)
            return -1;
        return smc_write("CH0C", &v, 1);
    }
    fprintf(stderr, "No supported charge-inhibit SMC key on this Mac\n");
    return -1;
}

static int set_adapter(int enabled) {
    if (smc_key_size("CHIE") == 1) {
        unsigned char v = enabled ? 0x00 : 0x08;
        return smc_write("CHIE", &v, 1);
    }
    if (smc_key_size("CH0I") == 1) {
        unsigned char v = enabled ? 0x00 : 0x01;
        return smc_write("CH0I", &v, 1);
    }
    fprintf(stderr, "No supported adapter-disable SMC key on this Mac\n");
    return -1;
}

static int key_is_nonzero(const char *key, int *found) {
    unsigned char buf[32];
    UInt32 n = 0;
    *found = 0;
    if (smc_read(key, buf, &n) != 0)
        return 0;
    *found = 1;
    for (UInt32 i = 0; i < n; i++)
        if (buf[i])
            return 1;
    return 0;
}

static int print_status(void) {
    int found, charging_inhibited = 0, adapter_disabled = 0, have_charge_key = 0, have_adapter_key = 0;
    const char *charge_keys[] = {"CHTE", "CH0B", "CH0C"};
    const char *adapter_keys[] = {"CHIE", "CH0I"};

    for (size_t i = 0; i < sizeof(charge_keys) / sizeof(*charge_keys); i++) {
        charging_inhibited |= key_is_nonzero(charge_keys[i], &found);
        have_charge_key |= found;
    }
    for (size_t i = 0; i < sizeof(adapter_keys) / sizeof(*adapter_keys); i++) {
        adapter_disabled |= key_is_nonzero(adapter_keys[i], &found);
        have_adapter_key |= found;
    }

    const char *mode = adapter_disabled ? "block" : charging_inhibited ? "inhibit" : "allow";
    printf("mode=%s\n", mode);
    printf("charge_control_supported=%d\n", have_charge_key);
    printf("adapter_control_supported=%d\n", have_adapter_key);
    return have_charge_key ? 0 : 1;
}

static void usage(const char *argv0) {
    fprintf(stderr, "usage: %s status|allow|inhibit|block\n", argv0);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        usage(argv[0]);
        return 2;
    }
    const char *cmd = argv[1];
    int is_write = strcmp(cmd, "allow") == 0 || strcmp(cmd, "inhibit") == 0 || strcmp(cmd, "block") == 0;
    if (!is_write && strcmp(cmd, "status") != 0) {
        usage(argv[0]);
        return 2;
    }
    if (is_write && geteuid() != 0) {
        fprintf(stderr, "%s %s must run as root\n", argv[0], cmd);
        return 1;
    }
    if (smc_open() != 0)
        return 1;

    int rc = 0;
    if (strcmp(cmd, "status") == 0) {
        rc = print_status();
    } else if (strcmp(cmd, "allow") == 0) {
        /* Re-enable the adapter first so the Mac never ends up with neither. */
        if (smc_key_size("CHIE") || smc_key_size("CH0I"))
            rc |= set_adapter(1);
        rc |= set_charging(1);
    } else if (strcmp(cmd, "inhibit") == 0) {
        if (smc_key_size("CHIE") || smc_key_size("CH0I"))
            rc |= set_adapter(1);
        rc |= set_charging(0);
    } else { /* block */
        rc |= set_charging(0);
        rc |= set_adapter(0);
    }

    IOServiceClose(conn);
    return rc ? 1 : 0;
}
