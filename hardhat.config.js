require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
require('dotenv').config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0,
      gasPrice: 0
      // allowUnlimitedContractSize: true,
      // forking: {
      //   url: process.env.FORKING_URL_ARBITRUM
      // },
      // mining: {
      //   auto: true,
      //   interval: [10000, 20000]
      // }
    },
    // rinkeby: {
    //   url: process.env.RINKEBY_URL,
    //   accounts: [process.env.RINKEBY_PKEY]
    // },
    // mainnet: {
    //   url: process.env.MAINNET_URL
    // },
    // arbitrum_rinkeby: {
    //   url: 'https://rinkeby.arbitrum.io/rpc',
    //   accounts: [process.env.RINKEBY_PKEY]
    // },
    arbitrum: {
      url: 'https://arb1.arbitrum.io/rpc',
      accounts: [process.env.ARBITRUM_PKEY, process.env.ARBITRUM_ORACLE_PKEY]
    },
    // avalanche: {
    //   url: 'https://api.avax.network/ext/bc/C/rpc',
    //   accounts: [process.env.AVALANCHE_PKEY]
    // }
  },
  solidity: {
    compilers: [{
      version: "0.8.16",
      settings: {
        viaIR: true,
        optimizer: {
          enabled: true,
          runs: 10
        }
      }
    }]
  }
};
