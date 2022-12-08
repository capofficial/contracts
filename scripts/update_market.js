const hre = require("hardhat");
const { ethers } = require('hardhat');
const { MARKETS, chainlinkFeeds } = require('./lib/markets.js');

async function main() {

  const network = hre.network.name;
  console.log('Network', network);

  const provider = ethers.provider;

  const [signer, _oracle] = await ethers.getSigners();

  // Account
  const account = await signer.getAddress();
  console.log('Account', account);

  const marketStore = await (await ethers.getContractFactory("MarketStore")).attach("0xb75386a3F75930207f7E7C649Ce93c994f3dee40");

  const market = 'BTC-USD';
  const marketInfo = MARKETS[market];

  const tx = await marketStore.set(market, marketInfo);
  const receipt = await tx.wait();

  console.log(receipt);

  // Fund pool store

  // // Create a transaction object
  // let tx = {
  //     to: "0x9cC87998ba85D81e017E6B7662aC00eE2Ab8fe13",
  //     // Convert asset unit from ether to wei
  //     value: ethers.utils.parseEther("100")
  // }
  // // Send a transaction
  // signer.sendTransaction(tx)
  // .then((txObj) => {
  //     console.log('txHash', txObj.hash)
  //     // => 0x9c172314a693b94853b49dc057cf1cb8e529f29ce0272f451eea8f5741aa9b58
  //     // A transaction result can be checked in a etherscan with a transaction hash which can be obtained here.
  // });

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});