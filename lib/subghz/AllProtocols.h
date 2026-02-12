#ifndef All_Protocols_h
#define All_Protocols_h

#include "protocols/Princeton.h"
#include "protocols/Raw.h"
#include "protocols/BinRAW.h"
#include "protocols/CAME.h"
#include "protocols/NiceFlo.h"
#include "protocols/GateTX.h"
#include "protocols/Holtek.h"
#include "protocols/Honeywell48.h"

namespace {
    struct RegisterAllProtocols {
        RegisterAllProtocols() {
            SubGhzProtocol::registerProtocol("Princeton", createPrincetonProtocol);
            SubGhzProtocol::registerProtocol("RAW", createRawProtocol);
            SubGhzProtocol::registerProtocol("BinRAW", createBinRAWProtocol);
            SubGhzProtocol::registerProtocol("CAME", createCAMEProtocol);
            SubGhzProtocol::registerProtocol("Nice FLO", createNiceFloProtocol);
            SubGhzProtocol::registerProtocol("Gate TX", createGateTXProtocol);
            SubGhzProtocol::registerProtocol("Holtek", createHoltekProtocol);
            SubGhzProtocol::registerProtocol("Honeywell 48bit", createHoneywell48Protocol);
        }
    };

    static RegisterAllProtocols registerAllProtocols;
}

#endif // All_Protocols_h
