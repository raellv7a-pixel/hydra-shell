// Copyright (C) 2025-2026 snowarch. Based on iNiR by snowarch (https://github.com/snowarch/inir).
// Modified for Hydra (2026-11-05): stable per-window ownership, independent of source readiness.
// GPL-3.0 with upstream NOTICE section 7 terms; see LICENSES/iNiR.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The chassis field's wallpaper backdrop, listed per window so other fields and panes in the same
// window sample it instead of decoding the wallpaper again. Only declared sources are listed: an item
// created here and parented into a window that later unloads crashed Quickshell on teardown.
Singleton {
    id: root

    property var providers: []

    // Only nonvisual leases live here. Typed Item properties are cleared by Qt
    // when their QObject dies; plain JS objects retain dead QObject wrappers.
    Component {
        id: leaseFactory
        QtObject {
            id: lease
            property Item host: null
            property Item owner: null
            property Item source: null
            onHostChanged: if (!host) root.discard(lease)
            onOwnerChanged: if (!owner) root.discard(lease)
        }
    }

    function discard(lease: QtObject): void {
        if (!root.providers.includes(lease)) return
        root.providers = root.providers.filter(p => p !== lease)
        lease.destroy()
    }

    function ownerFor(host: Item): Item {
        return root.providers.find(p => p.host === host && p.owner)?.owner ?? null
    }

    function claim(host: Item, owner: Item): void {
        if (!host || !owner || root.ownerFor(host)) return
        root.providers = root.providers.concat([leaseFactory.createObject(root, {host: host, owner: owner})])
    }

    function publish(host: Item, owner: Item, source: Item): void {
        const entry = root.providers.find(p => p.host === host && p.owner === owner)
        if (entry) entry.source = source
    }

    function release(owner: Item): void {
        for (const entry of root.providers)
            if (!entry.host || !entry.owner || entry.owner === owner) root.discard(entry)
    }

    function find(host: Item): Item {
        return root.providers.find(p => p.host === host && p.owner)?.source ?? null
    }
}
