// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import "../../contracts/stores/AssetStore.sol";
import "../../contracts/stores/DataStore.sol";
import "../../contracts/stores/FundStore.sol";
import "../../contracts/stores/FundingStore.sol";
import "../../contracts/stores/MarketStore.sol";
import "../../contracts/stores/OrderStore.sol";
import "../../contracts/stores/PoolStore.sol";
import "../../contracts/stores/PositionStore.sol";
import "../../contracts/stores/RebateStore.sol";
import "../../contracts/stores/ReferralStore.sol";
import "../../contracts/stores/RiskStore.sol";
import "../../contracts/stores/RoleStore.sol";
import "../../contracts/stores/StakingStore.sol";

import "../../contracts/utils/Governable.sol";
import "../../contracts/utils/Roles.sol";

import "../../contracts/api/Funding.sol";
import "../../contracts/api/Orders.sol";
import "../../contracts/api/Pool.sol";
import "../../contracts/api/Positions.sol";
import "../../contracts/api/Processor.sol";
import "../../contracts/api/Staking.sol";

import "../../contracts/mocks/MockChainlink.sol";
import "../../contracts/mocks/MockToken.sol";

// Deploying locally:
// 1. Start anvil
// 2. forge script scripts/foundry/Setup.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract SetupTest is Script {
    AssetStore public assetStore;
    DataStore public dataStore;
    FundStore public fundStore;
    FundingStore public fundingStore;
    MarketStore public marketStore;
    OrderStore public orderStore;
    PoolStore public poolStore;
    PositionStore public positionStore;
    RebateStore public rebateStore;
    ReferralStore public referralStore;
    RiskStore public riskStore;
    RoleStore public roleStore;
    StakingStore public stakingStore;

    Governable public governable;
    Roles public roles;

    Funding public funding;
    Orders public orders;
    Pool public pool;
    Positions public positions;
    Processor public processor;
    Staking public staking;

    MockChainlink public chainlink;
    MockToken public cap;
    MockToken public usdc;

    // constants
    bytes32 constant CONTRACT_ROLE = keccak256("CONTRACT");
    bytes32 constant ORACLE_ROLE = keccak256("ORACLE");

    // oracle
    address public oracle = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    function run() public {
        string memory mnemonic = "test test test test test test test test test test test junk";   
        (address deployer, uint256 privateKey) = deriveRememberKey(mnemonic, 0); 

        console.log("Deploying contracts with address", deployer);
        vm.startBroadcast(deployer);

        // Mock Tokens - CAP, USDC
        cap = new MockToken("CAP", "CAP", 18);
        console.log("Cap token deployed to", address(cap));
        usdc = new MockToken("USDC", "USDC", 6);
        console.log("USDC token deployed to", address(usdc));

        // Mock price store
        chainlink = new MockChainlink();
        console.log("MockChainlink deployed to", address(chainlink));

        // Governable
        governable = new Governable();
        console.log("Governable deployed to", address(governable));

        // RoleStore
        roleStore = new RoleStore();
        console.log("RoleStore deployed to", address(roleStore));

        console.log('--------');

        // DataStore
        dataStore = new DataStore();
        console.log("DataStore deployed to", address(dataStore));

        console.log('--------');

        // AssetStore
        assetStore = new AssetStore(roleStore);
        console.log("AssetStore deployed to", address(assetStore));

        // FundingStore
        fundingStore = new FundingStore(roleStore);
        console.log("FundingStore deployed to", address(fundingStore));

        // FundStore
        fundStore = new FundStore(roleStore);
        console.log("FundStore deployed to", address(fundStore));

        // MarketStore
        marketStore = new MarketStore(roleStore);
        console.log("MarketStore deployed to", address(marketStore));

        // OrderStore
        orderStore = new OrderStore(roleStore);
        console.log("OrderStore deployed to", address(orderStore));

        // PoolStore
        poolStore = new PoolStore(roleStore);
        console.log("PoolStore deployed to", address(poolStore));

        // PositionStore
        positionStore = new PositionStore(roleStore);
        console.log("PositionStore deployed to", address(positionStore));

        // RebateStore
        rebateStore = new RebateStore(roleStore, dataStore);
        console.log("RebateStore deployed to", address(rebateStore));

        // ReferralStore
        referralStore = new ReferralStore(roleStore);
        console.log("ReferralStore deployed to", address(referralStore));

        // RiskStore
        riskStore = new RiskStore(roleStore, dataStore);
        console.log("RiskStore deployed to", address(riskStore));

        // StakingStore
        stakingStore = new StakingStore(roleStore);
        console.log("StakingStore deployed to", address(stakingStore));

        // Handlers

        // Funding
        funding = new Funding(roleStore, dataStore);
        console.log("Funding deployed to", address(funding));

        // Orders
        orders = new Orders(roleStore, dataStore);
        console.log("Orders deployed to", address(orders));

        // Pool
        pool = new Pool(roleStore, dataStore);
        console.log("Pool deployed to", address(pool));

        // Positions
        positions = new Positions(roleStore, dataStore);
        console.log("Positions deployed to", address(positions));

        // Processor
        processor = new Processor(roleStore, dataStore);
        console.log("Processor deployed to", address(processor));

        // Staking
        staking = new Staking(roleStore, dataStore);
        console.log("Staking deployed to", address(staking));

        // CONTRACT SETUP //

        // Data

        // Contract addresses
        dataStore.setAddress("AssetStore", address(assetStore), true);
        dataStore.setAddress("FundingStore", address(fundingStore), true);
        dataStore.setAddress("FundStore", address(fundStore), true);
        dataStore.setAddress("MarketStore", address(marketStore), true);
        dataStore.setAddress("OrderStore", address(orderStore), true);
        dataStore.setAddress("PoolStore", address(poolStore), true);
        dataStore.setAddress("PositionStore", address(positionStore), true);
        dataStore.setAddress("RebateStore", address(rebateStore), true);
        dataStore.setAddress("ReferralStore", address(referralStore), true);
        dataStore.setAddress("RiskStore", address(riskStore), true);
        dataStore.setAddress("StakingStore", address(stakingStore), true);
        dataStore.setAddress("Funding", address(funding), true);
        dataStore.setAddress("Orders", address(orders), true);
        dataStore.setAddress("Pool", address(pool), true);
        dataStore.setAddress("Positions", address(positions), true);
        dataStore.setAddress("Processor", address(processor), true);
        dataStore.setAddress("Staking", address(staking), true);
        dataStore.setAddress("CAP", address(cap), true);
        dataStore.setAddress("USDC", address(usdc), true);
        dataStore.setAddress("Chainlink", address(chainlink), true);
        dataStore.setAddress("oracle", address(oracle), true);
        console.log("Data addresses configured.");

        // Link
        funding.link();
        orders.link();
        pool.link();
        positions.link();
        processor.link();
        staking.link();
        console.log("Contracts linked.");

        // Grant roles
        roleStore.grantRole(address(funding), CONTRACT_ROLE);
        roleStore.grantRole(address(orders), CONTRACT_ROLE);
        roleStore.grantRole(address(pool), CONTRACT_ROLE);
        roleStore.grantRole(address(positions), CONTRACT_ROLE);
        roleStore.grantRole(address(processor), CONTRACT_ROLE);
        roleStore.grantRole(address(staking), CONTRACT_ROLE);
        roleStore.grantRole(oracle, CONTRACT_ROLE); // oracle also trusted to execute eg closeMarkets
        roleStore.grantRole(oracle, ORACLE_ROLE); // oracle also trusted to execute eg closeMarkets
        console.log("Roles configured.");

        // Currencies
        assetStore.set(address(0), AssetStore.Asset(0.1 ether, address(0)));
        assetStore.set(address(usdc), AssetStore.Asset(100 * 10**6, address(0)));
        console.log("Assets configured.");

        // Markets
        marketStore.set(
            "ETH-USD",
            MarketStore.Market(
                "Ethereum / U.S. Dollar",   // name
                "crypto",                   // category
                address(0),                 // chainlinkFeed
                50,                         // maxLeverage
                10000,                      // maxDeviation
                10,                         // fee
                9900,                       // liqThreshold
                true,                       // allowChainlinkExecution
                false,                      // isClosed
                false                       // isReduceOnly
            )
        );
        marketStore.set(
            "BTC-USD",
            MarketStore.Market(
                'Bitcoin / U.S. Dollar',
                'crypto',
                address(0),
                50,
                10000,
                10,
                9900,
                true,
                false,
                false
            )
        );
        marketStore.set(
            "EUR-USD",
            MarketStore.Market(
                'Euro / U.S. Dollar',
                'fx',
                address(0),
                100,
                10000,
                3,
                9900,
                true,
                false,
                false
            )
        );
        marketStore.set(
            "XAU-USD",
            MarketStore.Market(
                'Gold / U.S. Dollar',
                'commodities',
                address(0),
                20,
                10000,
                10,
                9500,
                true,
                false,
                false
            )
        );

        console.log("Markets configured.");

        // Mint and approve some mock tokens

        usdc.mint(100000 * 10**6);
        usdc.approve(address(fundStore), 10**9 * 10**6);
        cap.mint(1000 ether);
        cap.approve(address(fundStore), 1000_000_000 ether);
        
        vm.stopBroadcast();

        (address user, uint256 privateKeyUser) = deriveRememberKey(mnemonic, 2); 
        console.log("Minting tokens with account", user);
        vm.startBroadcast(user);

        // To user1
        usdc.mint(100000 * 10**6);
        usdc.approve(address(fundStore), 10**9 * 10**6);
        cap.mint(1000 ether);
        cap.approve(address(fundStore), 1000_000_000 ether);

        console.log("Minted mock tokens.");

        vm.stopBroadcast();
    }
}
