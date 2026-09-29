#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

// [fork] The only option the DaveLewis360/shell fork adds.
//
// It lives under its own global `fork` key in shell.json, so no upstream section
// gains a key. An upstream build quarantines and preserves the block, which keeps a
// shared config file valid in both directions.

namespace caelestia::config {

class ForkBar : public settings::ObjectNode {
    CONFIG_NODE(ForkBar, settings::ObjectNode)

    // Put the bar along the top edge. Off: the upstream vertical bar on the left.
    CONFIG_PROPERTY(bool, horizontal, false)
};

class ForkConfig : public settings::ObjectNode {
    CONFIG_NODE(ForkConfig, settings::ObjectNode)

    CONFIG_SUBOBJECT(ForkBar, bar)
};

} // namespace caelestia::config
