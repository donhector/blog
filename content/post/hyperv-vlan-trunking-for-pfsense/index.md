---
title: "Hyper-V VLAN Trunking for Pfsense"
description: Enabling trunking on a Hyper-V Network Adapter
date: 2022-07-05T20:03:23+02:00
image: vlan.webp
math: false
hidden: false
comments: true
draft: true
tags: [
    "hyperv",
    "powershell",
    "networking",
    "pfsense",
    "virtualization"
]
categories: [
    "homelab",
]
---

## Intro

I've recently ordered one of those [Protectli](https://protectli.com/product/vp2410/)-like boxes from [Aliexpress](https://aliexpress.com/item/1005004302428997.html) to act as a Pfsense based physical router/firewall for my home network. The deal was too good to miss out during the Aliexpress Summer Sale. Way cheaper than the *Protectli* or a similar *Netgate* and comes with updated hardware: Intel Celeron N5105, 4x 2.5Gbe Ethernet ports, 8Gb RAM, 128Gb NVME, SIM slot (you could potentially use the SIM as redundant WAN gateway).

I paid just under 200 EUR including taxes and shipping.

Since the item is coming from China it will take a while to get here, but in the meantime, I've already started configuring the OS: Pfsense.

How, you might be wondering? Well, easy answer: Virtualization!

{{<figure src="https://c.tenor.com/7HUogy7rXs4AAAAC/feel-me-think-about-it.gif">}}

## Setup

I've setup a small virtual home lab in Hyper-V with:

- The *Default Switch* (comes default in Hyper-V and provides NATted access to the internet to any VMs connected to it)
- A new *Private* virtual switch. I've named this switch *Pfsense*
- VM running Pfsense (ie: *pfsense-0*)
  - This VM has 3 virtual network adapters:
    - Network Adapter connected to *Default Switch*, acting as the WAN port.
    - Network Adapter connected to *Pfsense* Switch, acting as one of the LAN ports
    - Network Adapter connected to *Pfsense* Switch, acting as one of the LAN ports
- 2x VMs running Win10 (ie: win10pro-0, win10pro-1)
  - They have just one network adapter:
    - Network Adapter connected to *Pfsense* Switch. This will act as port connected to one of the pfsense LAN ports

Here are some captures:

{{<figure src="switch_manager.png" caption="Virtual Switch Manager">}}

{{<figure src="pfsense-0_adapters.png" caption="Pfsense VM network adapters">}}

{{<figure src="client_adapter.png" caption="Client VM network adapter">}}

This worked well as it is.

Installed Pfsense 2.6 from the ISO into the *pfsense-0* VM and went through the initial command line setup, where I mapped the interfaces (it helps if you had written down the MAC addresses of the virtual adapters, so you know which MAC address should be your WAN interface and which MAC addresses should be your LAN interfaces)

Then went into one of the Win10 VMs and in an administrative command prompt ran:

```bash
ipconfig /release
ipconfig /renew
```

That gave the VM a DHCP IP from Pfsense. Than opened the web browser and typed in Pfsense's IP (you could also use the FQDN *hostname.domain*). Logged in and continued configuring things such as DHCP, DNS over TLS, Firewall rules, and of course VLANs (tags, assignments, dhcp)...

I won't go into the details on how to configure everything as there are too many tutorials available out there in the interwebs (Pfsense official documentation, Youtube, blogs, etc...).

Once I had everything configured to my liking, it was time to do some testing, and if everything was fine then I could go to *Diagnostics -> Backup & Restore* and save the configuration as XML. Once the Aliexpress box comes in the mail, I could restore that XML into it. Pfsense should let you re-configure the interface mappings during restore, so should be possible to restore on a device with different number of ports.

## Testing VLANs

As part of my Pfsense configuration I have 3 VLANs, with IDs 10, 20, and 30. Each VLAN interface has DHCP enabled and should lease IPs in the 10.1.10.1/24, 10.1.20.1/24, and 10.1.30.1/24 respectively.

In order to test that, I've set the VLAN ID to 30 in one of the client VMs, and rebooted.

{{<figure src="client_adapter_vlan.png" caption="Client VM network adapter VLAN settings">}}

Theory says it should get an IP in the 10.1.30.1/24 range but... **it didn't!!**

{{<figure src="https://c.tenor.com/BfiiGos2XIUAAAAC/rage-meme.gif" >}}

## Problem

What's going on? Well, it looks like in Hyper-V all adapters are untagged by default. We can see that by running:

```powershell
Get-VMNetworkAdapter -VMName "pfsense-0"
Get-VMNetworkAdapterVlan -VMName "pfsense-0"
```

Output looks like:

{{<figure src="pfsense-0_adapters_settings.png" caption="Default adapter properties ">}}

That means that the Pfsense VM network adapters are expecting untagged traffic, but our test client VM is sending tagged traffic (ie. VLAN 30). That's our problem.

To fix this, we need to configure the virtual network adapter that is backing the Pfsense VLAN 30 interface (*Interfaces -> Assignments*) so that is trunked to the desired VLAN(s). Have its MAC address handy as we will be using it in the next step.

{{<figure src="pfsense-assignments.png" caption="Interface Assignments">}}

**NOTE:** We use the MAC to filter out which of the 3 interfaces is the one we want as Hyper-V names them all the same (ie: Network Adapter) if you created them via Hyper-V's UI. Renaming virtual adapters is out of scope in this post.

To set the adapter in *Trunk* mode, we need to run Powershell as those settings are not exposed in Hyper-V's UI:

```powershell
Get-VMNetworkAdapter -VMName "pfsense-0" | Where-Object -property macaddress -eq "00155d500107" | Set-VMNetworkAdapterVlan -Trunk -AllowedVlanIdList "10,20,30,90" -NativeVlanId 1
```

Where:

`00155d500107` is the MAC address of the virtual adapter without the colons.

`-Trunk` sets the adapter as trunked

`-AllowedVlanIdList` is the list of VLAN Ids the interface will handle. You can use comma separated values like I did or ranges (ie: 2-100)

`NativeVlanId` is the default VLAN id, which should be ID 1 in Pfsense unless you changed it. The *NativeVlanId* should not part of the *AllowedVlanIdList*

After running the command you should see something like in the capture below.

{{<figure src="pfsense-0_adapters_settings_after.png" caption="Updated adapter properties ">}}

After that, our test VM providing VLAN ID 30 will now receive an address from the VLAN 30 DHCP server. In this case 10.100.30.x

{{<figure src="client_vlan30_dhcp.png" caption="DHCP from VLAN30Updated adapter properties ">}}

So that's how you do it. It would be great if Hyper-V could expose more networking options via UI but it is what it is. Not really surprised by this as it's the exact same picture in Linux with Libvirt and VMManager, only a subset of settings is exposed via UI.

Until next time!

{{<figure src="https://c.tenor.com/h5r89kKK1PcAAAAC/star-wars-hyperspeed.gif">}}
