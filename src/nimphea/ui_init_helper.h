// UI_Init_Helper — compiled bridge for daisy::UI::Init's
// std::initializer_list<UiCanvasDescriptor> parameter (Nim has no native
// initializer_list equivalent). Referenced by nimphea_ui_core via importcpp.
#ifndef UI_INIT_HELPER_H
#define UI_INIT_HELPER_H

#include <cstddef>
#include <cstdint>
#include "ui/UI.h"

void UI_Init_Helper(daisy::UI* ui,
                    daisy::UiEventQueue& eventQueue,
                    const daisy::UI::SpecialControlIds& controlIds,
                    const daisy::UiCanvasDescriptor* canvases,
                    size_t numCanvases,
                    uint16_t primaryDisplayId);

#endif // UI_INIT_HELPER_H