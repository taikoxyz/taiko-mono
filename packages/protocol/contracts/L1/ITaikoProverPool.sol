// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

interface ITaikoProverPool {
  function pickRandomProver(uint256 randomNumber) external view returns (address);
  function getProver(uint256 blockId) external view returns (address);
  function slash(address prover) external;
}