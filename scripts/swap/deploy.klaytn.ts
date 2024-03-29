import { ethers, upgrades } from "hardhat";
import { Etherman, HamsterSwap } from "../../typechain-types";

async function main() {
  const EthermanFactory = await ethers.getContractFactory("Etherman");
  const EthermanContract = (await EthermanFactory.deploy(
    "0xe4f05A66Ec68B54A58B17c22107b02e0232cC817"
  )) as unknown as Etherman;

  const SwapContract = await ethers.getContractFactory("HamsterSwap");
  const Swap = (await upgrades.deployProxy(SwapContract, [], {
    unsafeAllow: ["constructor", "delegatecall"],
  })) as unknown as HamsterSwap;

  await Swap.deployed();

  await EthermanContract.transferOwnership(Swap.address);

  await Swap.configure(
    ethers.BigNumber.from("4"),
    ethers.BigNumber.from("4"),
    [
      ethers.utils.getAddress("0x5a293a1e234f4c26251fa0c69f33c83c38c091ff"), // https://opensea.io/collection/the-meta-kongz-klaytn
      ethers.utils.getAddress("0x46dbdc7965cf3cd2257c054feab941a05ff46488"), // https://opensea.io/collection/mtdz-1
      ethers.utils.getAddress("0x3f635476023a6422478cf288ecaeb3fdcf025e9f"), // https://opensea.io/collection/g-rilla-official
      ethers.utils.getAddress("0x6b8f71aa8d5817d94056103886a1f07d12e78ce5"), // https://opensea.io/collection/syltare-official
      ethers.utils.getAddress("0x8f5aa6b6dcd2d952a22920e8fe3f798471d05901"), // https://opensea.io/collection/sunmiya-club-official
      ethers.utils.getAddress("0x2da32c00c3d0a77623cb13a371b24fffbafda4a7"), // https://opensea.io/collection/the-snkrz-nft
      ethers.utils.getAddress("0xe47e90c58f8336a2f24bcd9bcb530e2e02e1e8ae"), // https://opensea.io/collection/dogesoundclub-mates
      ethers.utils.getAddress("0xd643bb39f81ff9079436f726d2ed27abc547cb38"), // https://opensea.io/collection/puuvillasociety
      ethers.utils.getAddress("0x56d23f924cd526e5590ed94193a892e913e38079"), // https://opensea.io/collection/archeworld-land
      ethers.utils.getAddress("0xce70eef5adac126c37c8bc0c1228d48b70066d03"), // https://opensea.io/collection/bellygom-world-official
      ethers.utils.getAddress("0xa9f07b1260bb9eebcbaba66700b00fe08b61e1e6"), // https://opensea.io/collection/sheepfarm
      ethers.utils.getAddress("0x018200befc26d8d50c3caf4791bfb36a9217a1a2"), // https://opensea.io/collection/afk-battle-idle-princess-bb
      ethers.utils.getAddress("0x96a08c2ae33757c1d4d237450b74c41a12161636"), // https://opensea.io/collection/age-of-zen-heroes-images
      ethers.utils.getAddress("0xa513819bcc1e157c0567a652c4a775642b62a4ad"), // https://opensea.io/collection/klaykingdoms-502
    ],
    [],
    EthermanContract.address
  );

  console.log("HamsterSwap deployed at:", Swap.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
