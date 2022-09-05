import { config as loadDotEnv } from 'dotenv';
  loadDotEnv();
// --- core
// import '@nomiclabs/hardhat-ethers'; // AKA: hardhat-deploy-ethers
import '@typechain/hardhat';
import 'hardhat-deploy';

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-waffle";

// --- utility
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-solhint';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-abi-exporter';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import 'hardhat-spdx-license-identifier';
import 'solidity-coverage';

// --- additional hardhat cli tasks
import './tasks';

// https://hardhat.org/config/
const accounts = {
  mnemonic: process.env.DEPLOYER_MNEMONIC || 'test test test test test test test test test test test junk',
  // accountsBalance: "990000000000000000000",
};

module.exports = {
  defaultNetwork: 'hardhat',
  gasReporter: {
    enabled: process.env.IS_GAS_REPORTED_ENABLED === 'true',
    currency: 'USD',
  },
  abiExporter: [
    {
      path: './abi/flat',
      runOnCompile: true,
      clear: true,
      flat: true,
    },
    {
      path: './abi/raw',
      runOnCompile: true,
      clear: true,
      flat: false,
    },
  ],
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      },
      live: false,
      saveDeployments: true,
      tags: ['test', 'local'],
    },    
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts,
      chainId: 4,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasPrice: 5000000000,
      gasMultiplier: 2,
    },
  },
  watcher: {
    compilation: {
      tasks: ['compile'],
      files: ['./contracts'],
      verbose: true,
    },
    ci: {
      tasks: [
        'clean',
        { command: 'compile', params: { quiet: true } },
        {
          command: 'test',
          params: { noCompile: true, testFiles: ['*.test.ts'] },
        },
      ],
    },
  },
  paths: {
    sources: './contracts',
    deploy: 'deploy',
    deployments: 'deployments',
    imports: 'imports',
    tests: 'test',
  },
  solidity: {
    compilers: [
      {
        version: '0.8.9',
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  mocha: {
    timeout: 180000,
  },
};


// const config: HardhatUserConfig = {
//   solidity: "0.8.9",
// };

// export default config;
