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
    await MockedERC20.connect(owner).transfer(
      otherAccount.address,
      ethers.BigNumber.from(ethers.constants.WeiPerEther).mul(20)
    );

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
    expect(await Swap.whitelistedAddresses(MockedERC721.address)).to.be.true;
    expect(await Swap.whitelistedAddresses(MockedERC20.address)).to.be.true;
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
    await MockedERC20.connect(otherAccount).approve(
      Swap.address,
      ethers.BigNumber.from(ethers.constants.MaxInt256)
    );
    await MockedERC721.connect(otherAccount).setApprovalForAll(
      Swap.address,
      true
    );

    /**
     * @dev Expect initial values
     */
    expect(await MockedERC20.balanceOf(otherAccount.address)).eq(
      ethers.BigNumber.from(ethers.constants.WeiPerEther).mul(20)
    );
    expect(await MockedERC721.balanceOf(otherAccount.address)).eq(1);
    expect(await MockedERC721.ownerOf(2)).eq(otherAccount.address);

    expect(await MockedERC20.balanceOf(Swap.address)).eq(0);
    expect(await MockedERC721.balanceOf(Swap.address)).eq(0);

    /**
     * @dev Create and deposit proposal
     */
    const proposalId = "proposal_1";
    const offeredItems = [
      {
        id: "offeredItem_1",
        contractAddress: MockedERC20.address,
        itemType: 1,
        amount: ethers.BigNumber.from((10 * 10 ** 18).toString()),
        tokenId: 1,
      },
      {
        id: "offeredItem_2",
        contractAddress: MockedERC20.address,
        itemType: 1,
        amount: ethers.BigNumber.from((10 * 10 ** 18).toString()),
        tokenId: 1,
      },
      {
        id: "offeredItem_3",
        contractAddress: MockedERC721.address,
        itemType: 0,
        amount: 1,
        tokenId: 2,
      },
    ];
    const askingItems = [
      {
        id: "option_1",
        askingItems: [
          {
            id: "askingItem_1",
            contractAddress: MockedERC721.address,
            amount: 1,
            tokenId: 1,
            itemType: 0,
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
      askingItems,
      expiredAt
    );

    /**
     * @dev Expect
     */
    const proposal = await Swap.proposals(proposalId);

    /**
     * @dev Expect initial values
     */
    expect(proposal.id).eq(proposalId);
    expect(proposal.status).eq(1); // which means the status is deposited
    expect(proposal.expiredAt).eq(expiredAt);
    expect(proposal.owner).eq(otherAccount.address);
    expect(proposal.fulfilledBy).eq(ethers.constants.AddressZero);
    expect(proposal.fulfilledByOptionId).eq("");

    /**
     * @dev Expect items and options
     */
    const [items, options] = await Swap.getProposalItemsAndOptions(proposalId);

    /**
     * @dev Expect offered items have been recoded properly
     */
    offeredItems.map((item, index) => {
      expect(item.id).eq(items[index].id);
      expect(item.itemType).eq(items[index].itemType);
      expect(item.amount).eq(items[index].amount);
      expect(item.contractAddress).eq(items[index].contractAddress);
      expect(items[index].owner).eq(otherAccount.address); // owner is recorded properly
      expect(items[index].status).eq(1); // status changed to deposited

      if (item.itemType === 1) {
        expect(items[index].tokenId).eq(0);
      } else {
        expect(item.tokenId).eq(items[index].tokenId);
      }
    });

    /**
     * @dev Expect options have been recorded properly
     */
    askingItems.map((elm, index) => {
      expect(elm.id).eq(options[index].id);

      elm.askingItems.map((item, itemIndex) => {
        expect(item.id).eq(options[index].askingItems[itemIndex].id);
        expect(item.itemType).eq(
          options[index].askingItems[itemIndex].itemType
        );
        expect(item.amount).eq(options[index].askingItems[itemIndex].amount);
        expect(item.contractAddress).eq(
          options[index].askingItems[itemIndex].contractAddress
        );
        expect(item.tokenId).eq(options[index].askingItems[itemIndex].tokenId);

        expect(options[index].askingItems[itemIndex].status).eq(0); // status has been recoded as created
        expect(options[index].askingItems[itemIndex].owner).eq(
          ethers.constants.AddressZero
        ); // status has been recoded as created
      });
    });

    /**
     * @dev After transferring to the contract, the balance will be empty
     */
    expect(await MockedERC20.balanceOf(otherAccount.address)).eq(0);
    expect(await MockedERC721.balanceOf(otherAccount.address)).eq(0);

    expect(await MockedERC20.balanceOf(Swap.address)).eq(
      ethers.BigNumber.from(ethers.constants.WeiPerEther).mul(20)
    );
    expect(await MockedERC721.balanceOf(Swap.address)).eq(1);
    expect(await MockedERC721.ownerOf(2)).eq(Swap.address);
  });
});
