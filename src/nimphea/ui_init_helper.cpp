// UI_Init_Helper — compiled bridge for daisy::UI::Init's
// std::initializer_list<UiCanvasDescriptor> parameter.
// See the matching header (nimphea_ui_core imports this via .compile).
#include "ui_init_helper.h"

void UI_Init_Helper(daisy::UI* ui,
                    daisy::UiEventQueue& eventQueue,
                    const daisy::UI::SpecialControlIds& controlIds,
                    const daisy::UiCanvasDescriptor* canvases,
                    size_t numCanvases,
                    uint16_t primaryDisplayId)
{
    // Build the initializer_list from an array using brace initialization.
    // UI_MAX_CANVASES is 8; anything beyond is ignored.
    switch(numCanvases)
    {
        case 0: ui->Init(eventQueue, controlIds, {}, primaryDisplayId); break;
        case 1: ui->Init(eventQueue, controlIds, {canvases[0]}, primaryDisplayId); break;
        case 2: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1]}, primaryDisplayId); break;
        case 3: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2]}, primaryDisplayId); break;
        case 4: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2], canvases[3]}, primaryDisplayId); break;
        case 5: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2], canvases[3], canvases[4]}, primaryDisplayId); break;
        case 6: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2], canvases[3], canvases[4], canvases[5]}, primaryDisplayId); break;
        case 7: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2], canvases[3], canvases[4], canvases[5], canvases[6]}, primaryDisplayId); break;
        case 8: ui->Init(eventQueue, controlIds, {canvases[0], canvases[1], canvases[2], canvases[3], canvases[4], canvases[5], canvases[6], canvases[7]}, primaryDisplayId); break;
        default: break; // Max 8 canvases (UI_MAX_CANVASES)
    }
}