// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/src/Script.sol";

abstract contract BaseScript is Script {
    constructor() {}

    modifier broadcast() {
        // Should be able to use --account deployer in keystore to specify account
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }
}
