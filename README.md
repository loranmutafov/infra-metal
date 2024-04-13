# Bare-metal NixOS fleet

This project is a bunch of Intel NUCs and Mac Minis working together in a Tailscale network, all either running NixOS or provisioned by Nix, set up in a few different locations for added resiliency. Some are in Varna, and some in London.

I work on creating resilient and scalable systems, and this project is my way of learning technologies in more depth. It's both a ground for experimentation, but also runs a few production services and websites.

You're very welcome to take a look and use parts of it in your own projects.

I always appreciate feedback and ideas, so feel free to open issues with suggestions. Or if you think something can be improved without changing its purpose or function, feel free to open a PR.

Thanks to Nico D'Cotta for getting me into this massive rabbit hole by saying "oh have you tried NixOS", when I told him I've bought 5 NUCs to move onto bare metal from Contabo. I've taken heavy inspiration from his selfhosted project:
https://github.com/Cottand/selfhosted

# Setup

- [Install NixOS](#install-nixos)
- [Set it up](#set-it-up)
- [Deploy](#deploy)

## Install NixOS

This first step is always manual, unless you have something like a PiKVM that may be able to automate it. But I don't have one, so I'm not sure how that'd work.

When installing NixOS, I set up a separate partition, as I'm using Ceph as my storage cluster. On a 500GB disk my partitions look something like this:

| Name  | File system | Flags | Mount point | Size                    |
| ----- | ----------- | ----- | ----------- | ----------------------- |
| Boot  | FAT32       | boot  | /boot       | 512 MiB                 |
| NixOS | ext4        |       | /           | 118024 MiB (leftover)   |
| Ceph  | XFS         |       |             | 358400 MiB / 350.00 GiB |


## Set it up

Once NixOS is installed, I perform a few actions before Colmena can take over.

### Enable ssh
Log into the machine and edit configuration.nix

```sh
sudo nano /etc/nixos/configuration.nix
```

You'll see a commented out line for ssh - uncomment it
```nix
# Enable the OpenSSH daemon.
# services.openssh.enable = true;
```

Optionally (I like to be explicit about firewall rules, but NixOS usually allows port 22 when you enable ssh), enable the firewall and allow port 22. There should usually be a commented out firewall block a couple lines below the ssh line:
```nix
networking.firewall.allowedTCPPorts = [ 22 ];
```

Apply your changes:

In nano:
- <kbd>^ Control</kbd> + <kbd>O</kbd> to write out your changes
- <kbd>Y</kbd> to save in the directory it's asking you to
- <kbd>^ Control</kbd> + <kbd>X</kbd> to exit

Then in the shell:
```shell
sudo nixos-rebuild switch
```

Check the local address of the machine
```shell
ifconfig
```

### Add your key and enable agent forwarding

To deploy with Colmena without having to type in passwords at every turn, you can authenticate your machine's private key to ssh and perform sudo actions.

From your machine, get your public key and add it to the clipboard (assuming macOS)
```shell
ssh-add -L | pbcopy
```

Assuming the machine is currently on `192.168.0.10`, ssh into it
```shell
ssh YOUR_USER@192.168.0.10
```

Open `configuration.nix` again
```shell
sudo nano /etc/nixos/configuration.nix
```

Add the following line into the `users.users.YOUR_USER` block:
```nix
openssh.authorizedKeys.keys = [
  "PASTE_YOUR_PUBLIC_KEY_HERE"
];
```

Then allow sudo via agent forwarding via this key, adding the following lines:
```nix
security.pam.enableSSHAgentAuth = true;
security.pam.services.sudo.sshAgentAuth = true;
```

Apply the changes:
<kbd>^ Control</kbd> + <kbd>X</kbd>; <kbd>Y</kbd> to save and exit from nano

```shell
sudo nixos-rebuild switch
```

To confirm the above works, exit the ssh session
```shell
exit
```

When logging back in, you shouldn't be prompted for a password anymore:
```shell
ssh -A YOUR_USER@192.168.0.10
```

And as we've enabled agent forwarding (`-A`), you shouldn't be prompted for a password for sudo actions either. Test this out by attempting to edit `configuration.nix` again:
```shell
sudo nano /etc/nixos/configuration.nix
```

If everything above works, then congratulations, your machine is ready to start being deployed to via Colmena. I recommend setting up a Wireguard or Tailscale network, or making your machine discoverable via a Cloudflare Tunnel. I use both Tailscale and Cloudflare tunnels to have some redundancy in case one goes down or I mess up its configuration.

To automate agent forwarding in ssh, if you have a static name for your machine (via a VPN or CF tunnel), you can add the following to your `~/.ssh/config`:
```
Host your-machine.tld your-other-machine
  ForwardAgent yes
```

## Deploy

Now that the manual steps are out of the way, I'd add the machine under `/machines` in this repo, and perform a `make deploy`. This will invoke my custom deploy script, which:
1. makes sure some packages are present on the machine I'm running it from
2. connects to Tailscale
3. and executes `colmena apply`

From this point on, deploying changes is as simple as modifying the nix configuration on my machine, and executing:

```shell
make deploy
```

# Licence
Infra-Metal is distributed under the [BSD 3-Clause Licence](https://github.com/loranmutafov/infra-metal/blob/main/LICENCE).
