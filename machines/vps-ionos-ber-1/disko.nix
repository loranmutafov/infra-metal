{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        # IONOS classic VPS uses SeaBIOS (legacy BIOS), not UEFI.
        # GRUB on a GPT disk needs a tiny BIOS Boot Partition (type EF02)
        # to embed its core.img, since there's no MBR gap on GPT.
        bios = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };
        bluestore = {
          size = "400G";
          # No `content`: leaves the partition raw for Ceph bluestore.
          # Ceph will own this device end-to-end.
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
