// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ERC721MerkleDrop is ERC721 {
    bytes32 public immutable root;

    mapping(uint256 => uint256) private _availableTokens;
    uint256 private _numAvailableTokens;

    mapping (address => bool) private _redeemed;

    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkleroot,
        uint256 supply
    ) ERC721(name, symbol) {
        root = merkleroot;
        _numAvailableTokens = supply;
    }

    function redeem(address account, bytes32[] calldata proof) external {
        require(tx.origin == msg.sender); //prevent function call from contracts
        require(_verify(_leaf(account), proof), "Invalid merkle proof");
        require(_numAvailableTokens>0, "Out of supply");
        require(!_redeemed[account], "Already redeemed");
        
        _safeMint(account, _randomTokenId(account, _numAvailableTokens));
        --_numAvailableTokens;
        _redeemed[account] = true;
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _verify(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, root, leaf);
    }

    function _vrf() internal view returns (bytes32 result) {
        uint256[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
    }

    function _randomTokenId(address account, uint256 numAvailableTokens)
        internal
        returns (uint256)
    {
        uint256 randomIndex = (uint256(
            keccak256(abi.encodePacked(uint256(_vrf()), account))
        ) % 100) % numAvailableTokens;
        return _getAvailableTokenAtIndex(randomIndex, numAvailableTokens);
    }

    function _getAvailableTokenAtIndex(
        uint256 indexToUse,
        uint256 numAvailableTokens
    ) internal returns (uint256) {
        uint256 valAtIndex = _availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = numAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                _availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                _availableTokens[indexToUse] = lastValInArray;
                // Gas refund courtsey of @dievardump
                delete _availableTokens[lastIndex];
            }
        }

        return result;
    }
}
