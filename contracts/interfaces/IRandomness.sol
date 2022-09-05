// SPDX-License-Identifier: ISC



pragma solidity ^0.8.0;

interface IRandomness {
  	function getRandom(uint256 seed) external view returns (uint256);
}