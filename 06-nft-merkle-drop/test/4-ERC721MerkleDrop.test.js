const { ethers } = require('hardhat');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { expect } = require('chai');
const tokens = require('./tokens.json');

async function deploy(name, ...params) {
  const Contract = await ethers.getContractFactory(name);
  return await Contract.deploy(...params).then(f => f.deployed());
}

function hashToken(account) {
  return Buffer.from(ethers.utils.solidityKeccak256(['address'], [account]).slice(2), 'hex')
}


describe('ERC721MerkleDrop', function () {
  before(async function() {
    this.accounts = await ethers.getSigners();
    this.merkleTree = new MerkleTree(Object.keys(tokens).map(account => hashToken(account)), keccak256, { sortPairs: true });
  });

  describe('Mint all elements', function () {
    before(async function() {
      this.registry = await deploy('ERC721MerkleDrop', 'Name', 'Symbol', this.merkleTree.getHexRoot(), 100);
    });

    for (const [account, tokenId] of Object.entries(tokens)) {
      it('element', async function () {
        /**
         * Create merkle proof (anyone with knowledge of the merkle tree)
         */
        const proof = this.merkleTree.getHexProof(hashToken(account));
        /**
         * Redeems token using merkle proof (anyone with the proof)
         */
        await expect(this.registry.redeem(account, proof))
          .to.emit(this.registry, 'Transfer')
          .withArgs(ethers.constants.AddressZero, account, tokenId);
      });
    }
  });

  describe('Duplicate mint', function () {
    before(async function() {
      this.registry = await deploy('ERC721MerkleDrop', 'Name', 'Symbol', this.merkleTree.getHexRoot(), 100);

      this.token = {};
      [ this.token.account, this.token.tokenId ] = Object.entries(tokens).find(Boolean);
      this.token.proof = this.merkleTree.getHexProof(hashToken(this.token.account));
    });

    it('mint once - success', async function () {
      await expect(this.registry.redeem(this.token.account, this.token.proof))
        .to.emit(this.registry, 'Transfer')
        .withArgs(ethers.constants.AddressZero, this.token.account, this.token.tokenId);
    });

    it('mint twice - failure', async function () {
      await expect(this.registry.redeem(this.token.account, this.token.proof))
        .to.be.revertedWith('Already redeemed');
    });
  });

  describe('Frontrun', function () {
    before(async function() {
      this.registry = await deploy('ERC721MerkleDrop', 'Name', 'Symbol', this.merkleTree.getHexRoot(), 100);

      this.token = {};
      [ this.token.account, this.token.tokenId ] = Object.entries(tokens).find(Boolean);
      this.token.proof = this.merkleTree.getHexProof(hashToken(this.token.account));
    });

    it('prevented', async function () {
      await expect(this.registry.redeem(this.accounts[0].address, this.token.proof))
        .to.be.revertedWith('Invalid merkle proof');
    });
  });
});
