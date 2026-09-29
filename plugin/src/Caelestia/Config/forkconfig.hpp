#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

// [fork] The options the DaveLewis360/shell fork adds.
//
// They live under their own global `fork` key in shell.json, so no upstream section
// gains a key. An upstream build quarantines and preserves the block, which keeps a
// shared config file valid in both directions.

namespace caelestia::shell::config {

class ForkBar : public settings::ObjectNode {
    CONFIG_NODE(ForkBar, settings::ObjectNode)

    // Put the bar along the top edge. Off: the upstream vertical bar on the left.
    CONFIG_PROPERTY(bool, horizontal, false)
    // Show the Num Lock icon of the lock keys status entry, in both bars. Off hides
    // it for keyboards that keep Num Lock on all the time; Caps Lock still shows.
    CONFIG_PROPERTY(bool, showNumLock, true)
};

class ForkConfig : public settings::ObjectNode {
    CONFIG_NODE(ForkConfig, settings::ObjectNode)

    CONFIG_SUBOBJECT(ForkBar, bar)
};

} // namespace caelestia::shell::config
