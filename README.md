# NFT Fair Drop Primitives
To allow builders on Harmony to implement a fair NFT drop easily, this repo provides the primitives needed to develop such a smart contract.

## Starting point
This repo is forked from the OpenZeppelin ["Building an NFT Merkle-Drop"](https://blog.openzeppelin.com/workshop-recap-building-an-nft-merkle-drop/) workshop.

The initial design hashes the minter address and the token ID together and commits into a Merkle Tree, from which the root is included in the smart contract constructor.

## Step 1: adding Harmony's VRF (Verifiable Random Function)
[Harmony VRF](https://docs.harmony.one/home/developers/tools/harmony-vrf) is a source of unpredictable, unbiasable, and verifiable rnaodmness that is available for every single block through a precompiled contract. To access it, simply include the following code snippet:

```
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
```

## Step 2: adapt the Merkle tree construction
Since token ID is now randomly selected with VRF, we have to remove token ID from the Merkle tree construction. 

See [this commit](https://github.com/socathie/fairdrop/commit/4194e6665ae790255fb5fd9e32b734133912cd18).

## Step 3: generate token ID using new randomness

### [WRONG] Attempt #1: Naive random token ID
A naive solution to use our `_vrf` function to generate a token ID between 0 and 99 (assuming our supply is 100) is to do this:
```
    function _randomTokenId(address account) internal view returns (uint256 tokenId) {
        tokenId = (uint256(keccak256(abi.encodePacked(uint256(_vrf()),account))) % 100);
    }
```
This naive solution is incorrect because it's likely that token IDs generated this way might collide in different mints and causing the `redeem` transaction to revert.

### [CORRECT] Attemp #2: Fisher–Yates shuffle algorithm
To efficiently pick the next available random ID, we use the modern version of Fisher-Yates algorithm to 
```
    function _randomTokenId(address account, uint256 numAvailableTokens)
        internal
        returns (uint256)
    {
        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(uint256(_vrf()), account))
        ) % numAvailableTokens;
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
```

For more detailed explanation, please refer to this article on [ERC721R](https://mirror.xyz/0x9B5b7b8290c23dD619ceaC1ebcCBad3661786f3a/3JDsm6Gm-m_fNRvNEjflXYkmPxZQ-zhoa3fBi8X5Kdg
).

## Known limitations
* Front running is still possible if the `redeem` function is called by a smart contract. To prevent this, do:
```
    require(tx.origin == msg.sender);
```
* Since token ID has been removed from Merkle tree construction, to avoid double minting, each address can only be included in the tree at most once and redemption is tracked by the mapping `_redeemed`.


## References
1. https://blog.openzeppelin.com/workshop-recap-building-an-nft-merkle-drop/
2. https://mirror.xyz/0x9B5b7b8290c23dD619ceaC1ebcCBad3661786f3a/3JDsm6Gm-m_fNRvNEjflXYkmPxZQ-zhoa3fBi8X5Kdg
3. https://docs.harmony.one/home/developers/tools/harmony-vrf
