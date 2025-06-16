//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <availability_scheduling/availability_scheduling_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) availability_scheduling_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AvailabilitySchedulingPlugin");
  availability_scheduling_plugin_register_with_registrar(availability_scheduling_registrar);
}
