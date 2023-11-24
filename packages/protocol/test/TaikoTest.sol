// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/bridge/Bridge.sol";
import "../contracts/signal/SignalService.sol";
import "../contracts/common/ICrossChainSync.sol";
import "../contracts/common/EssentialContract.sol";
import "../contracts/libs/LibDeployHelper.sol";

abstract contract TaikoTest is Test {
    uint256 private _seed = 0x12345678;
    address internal Alice = vm.addr(0x1);
    address internal Bob = vm.addr(0x2);
    address internal Carol = vm.addr(0x3);
    address internal David = randAddress();
    address internal Emma = randAddress();
    address internal Frank = randAddress();
    address internal Grace = randAddress();
    address internal Henry = randAddress();
    address internal Isabella = randAddress();
    address internal James = randAddress();
    address internal Katherine = randAddress();
    address internal Liam = randAddress();
    address internal Mia = randAddress();
    address internal Noah = randAddress();
    address internal Olivia = randAddress();
    address internal Patrick = randAddress();
    address internal Quinn = randAddress();
    address internal Rachel = randAddress();
    address internal Samuel = randAddress();
    address internal Taylor = randAddress();
    address internal Ulysses = randAddress();
    address internal Victoria = randAddress();
    address internal William = randAddress();
    address internal Xavier = randAddress();
    address internal Yasmine = randAddress();
    address internal Zachary = randAddress();
    address internal SGX_X_0 = vm.addr(0x4);
    address internal SGX_X_1 = vm.addr(0x5);
    address internal SGX_Y = randAddress();
    address internal SGX_Z = randAddress();

    function randAddress() internal returns (address) {
        bytes32 randomHash = keccak256(abi.encodePacked("address", _seed++));
        return address(bytes20(randomHash));
    }

    function randBytes32() internal returns (bytes32) {
        return keccak256(abi.encodePacked("bytes32", _seed++));
    }
}

contract BadReceiver {
    receive() external payable {
        revert("can not send to this contract");
    }

    fallback() external payable {
        revert("can not send to this contract");
    }

    function transfer() public pure {
        revert("this fails");
    }
}

contract GoodReceiver {
    receive() external payable { }

    function forward(address addr) public payable {
        payable(addr).transfer(address(this).balance / 2);
    }
}

// NonNftContract
contract NonNftContract {
    uint256 dummyData;

    constructor(uint256 _dummyData) {
        dummyData = _dummyData;
    }
}

contract SkipProofCheckSignal is SignalService {
    function skipProofCheck() public pure override returns (bool) {
        return true;
    }
}

contract DummyCrossChainSync is EssentialContract, ICrossChainSync {
    Snippet private _snippet;

    function setSyncedData(bytes32 blockHash, bytes32 signalRoot) external {
        _snippet.blockHash = blockHash;
        _snippet.signalRoot = signalRoot;
    }

    function getSyncedSnippet(uint64) external view returns (Snippet memory) {
        return _snippet;
    }
}
