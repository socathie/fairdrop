require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('hardhat-gas-reporter');

// Replace this private key with your Harmony account private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Be aware of NEVER putting real Ether into testing accounts
const HARMONY_PRIVATE_KEY = "insert private key here";

const settings = {
  optimizer: {
    enabled: true,
    runs: 200,
  },
};

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      { version: '0.8.4', settings },
      { version: '0.7.6', settings },
      { version: '0.6.12', settings },
      { version: '0.5.16', settings },
    ],
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP,
    gasPrice: 200,
  },
  networks: {
    hardhat: {
      gas: 100000000,
      blockGasLimit: 0x1fffffffffffff,
      forking: {
        enabled: false,
        url: "https://api.s0.ps.hmny.io/"
      }
    },
    devnet: {
      url: "https://api.s0.ps.hmny.io/",
      chainId: 1666900000,
      accounts: [`${HARMONY_PRIVATE_KEY}`]
    },
    mainnet: {
      url: "https://api.s0.t.hmny.io",
      chainId: 1666600000,
      accounts: [`${HARMONY_PRIVATE_KEY}`]
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  paths: {
    deploy: "deploy",
    deployments: "deployments",
  },
  mocha: {
    timeout: 1000000
  }
};
