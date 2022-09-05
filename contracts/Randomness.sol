// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Randomness is Ownable {
    address private caller;

    constructor() {}

    function getRandom(uint256 seed) external view returns (uint256) {
        require(msg.sender == caller, "invalid caller");
        return random(seed);
    }

    function random(uint256 seed) private view returns (uint256 _rand) {
        _rand = uint256(keccak256(abi.encodePacked(seed, tx.origin, blockhash(block.number - 1), block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) + block.number)));
    }

    function updateCaller(address _caller) external onlyOwner {
        caller = _caller;
    }
}
