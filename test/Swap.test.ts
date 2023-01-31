import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HamsterSwap } from "../typechain-types";

describe("HamsterSwap", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployFixtures() {
    /**
     * @dev Initializes mocked erc contracts
     */
    const MockedERC20Contract = await ethers.getContractFactory("MockedERC20");
    const MockedERC20 = await MockedERC20Contract.deploy();

    const MockedERC721Contract = await ethers.getContractFactory(
      "MockedERC721"
    );
    const MockedERC721 = await MockedERC721Contract.deploy();

    /**
     * @dev Mint erc721
     */
    const [owner, otherAccount] = await ethers.getSigners();
    await MockedERC721.connect(owner).safeMint(owner.address, "1");
    await MockedERC721.connect(owner).safeMint(otherAccount.address, "2");

    /**
     * @dev Funding erc20
     */
    MockedERC20.connect(owner).transfer(otherAccount.address, 1000 * 10 ** 18);

    /**
     * @dev Deploy contract
     */
    const SwapContract = await ethers.getContractFactory("HamsterSwap");
    const Swap = (await upgrades.deployProxy(SwapContract, [], {
      unsafeAllowCustomTypes: true,
    })) as HamsterSwap;

    /**
     * @dev Configure registry
     */
    await Swap.connect(owner).configure(
      "3",
      "4",
      [MockedERC721.address, MockedERC20.address],
      []
    );

    /**
     * @dev return
     */
    return { Swap, MockedERC20, MockedERC721, owner, otherAccount };
  }

  it("Should: admin can configure swap registry", async function () {
    const { Swap, MockedERC20, MockedERC721 } = await loadFixture(
      deployFixtures
    );

    /**
     * @dev Expect
     */
    expect(await Swap.whitelistedItemAddresses(MockedERC721.address)).to.be
      .true;
    expect(await Swap.whitelistedItemAddresses(MockedERC20.address)).to.be.true;
    expect(await Swap.maxAllowedItems()).to.eq("3");
    expect(await Swap.maxAllowedOptions()).to.eq("4");
  });

  it("Should: anyone can create proposal and deposit items", async () => {
    const { Swap, MockedERC20, MockedERC721, otherAccount } = await loadFixture(
      deployFixtures
    );

    /**
     * @dev Approve first
     */
    MockedERC20.connect(otherAccount).approve(Swap.address, 2 ** 256 - 1);
    MockedERC721.connect(otherAccount).setApprovalForAll(Swap.address, true);

    /**
     * @dev Create and deposit proposal
     */
    const proposalId = "proposal_1";
    const offeredItems = [
      {
        id: "offeredItem_1",
        contractAddress: MockedERC20.address,
        owner: otherAccount.address,
        itemType: 2,
        amount: ethers.BigNumber.from((10 * 10 ** 18).toString()),
        tokenId: 1,
        status: 1,
      },
    ];
    const askingItems = [
      {
        id: "option_1",
        askingItems: [
          {
            id: "askingItem_1",
            contractAddress: MockedERC721.address,
            owner: otherAccount.address,
            amount: 1,
            tokenId: 1,
          },
        ],
      },
    ];
    const expiredAt =
      parseInt((new Date().getTime() / 1000).toString()) + 60 * 60;

    /**
     * @dev Call contract
     */
    await Swap.connect(otherAccount).createProposal(
      proposalId,
      offeredItems,
      // askingItems,
      expiredAt
    );

    /**
     * @dev Expect
     */
    console.log(await Swap.proposals(proposalId));
  });
});
