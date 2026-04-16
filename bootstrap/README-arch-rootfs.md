<h1>Arch RootFS Single-Entry Reinstall Template</h1>
<h2>Main entry</h2>
<p>Recommended for normal use:</p>
<pre><code>curl -sSL https://raw.githubusercontent.com/fxxzz/123/main/bootstrap/bootstrap-rootfs.sh | bash
</code></pre>
<p>Also supported for local debugging:</p>
<pre><code>cd bootstrap
bash bootstrap-rootfs.sh
</code></pre>
<h2>Files</h2>
<ul>
<li><code>bootstrap-rootfs.sh</code> — single entry; partitions disk, downloads bootstrap rootfs, mounts target, enters chroot</li>
<li><code>config.sh</code> — main configuration knobs</li>
<li><code>setup-chroot.sh</code> — runs inside the target system chroot</li>
<li><code>firstboot.sh</code> — minimal one-shot cleanup on first boot</li>
<li><code>systemd/firstboot.service</code> — systemd oneshot unit for first boot cleanup</li>
</ul>
<h2>Default behavior</h2>
<ul>
<li>target disk: <code>/dev/vda</code></li>
<li>partitions: <code>1G EFI + remaining ext4 root</code></li>
<li>hostname: <code>arch</code></li>
<li>timezone: <code>Asia/Hong_Kong</code></li>
<li>locale: <code>en_US.UTF-8</code></li>
<li>network: <code>systemd-networkd + systemd-resolved</code></li>
<li>IPv4: DHCP</li>
<li>IPv6: static (<code>2a0a:4cc0:2000:30eb::1/64</code>, gateway <code>fe80::1</code>)</li>
<li>SSH: <code>PermitRootLogin yes</code>, <code>PasswordAuthentication no</code></li>
<li>root password: configured in <code>config.sh</code></li>
<li>root SSH public key: configured in <code>config.sh</code></li>
</ul>
<h2>Notes</h2>
<ul>
<li>This template assumes a VPS/server-style environment and UEFI boot.</li>
<li>Review <code>config.sh</code> before use.</li>
<li>Adjust package list conservatively if you want a smaller footprint.</li>
<li>Keep your real repository on a fixed tag/commit when you are done iterating.</li>
</ul>
