// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ERC721MerkleDrop is ERC721 {
    bytes32 public immutable root;

    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkleroot
    ) ERC721(name, symbol) {
        root = merkleroot;
    }

    function redeem(
        address account,
        uint256 tokenId,
        bytes32[] calldata proof
    ) external {
        require(
            _verify(_leaf(account, tokenId), proof),
            "Invalid merkle proof"
        );
        _safeMint(account, _randomTokenId(account));
    }

    function _leaf(address account, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(tokenId, account));
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

    function _randomTokenId(address account) internal view returns (uint256 tokenId) {
        tokenId = (uint256(keccak256(abi.encodePacked(uint256(_vrf()),account))) % 100)  + 1;
    }
}
