// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./Entity.sol";
import "./Params.sol";

/**
 * @notice HamsterSwap which is a trustless p2p exchange,
 * handles NFT-NFT, NFT-Currency and Currency-Currency swap transactions.
 **/
/// @custom:security-contact khang@cavies.xyz
contract HamsterSwap is
	Initializable,
	PausableUpgradeable,
	OwnableUpgradeable,
	IERC721Receiver
{
	/**
	 * @dev Administration configurations
	 */
	uint256 public maxAllowedItems;
	uint256 public maxAllowedOptions;
	mapping(address => bool) public whitelistedAddresses;

	/**
	 * @dev Storing proposal data inside a mapping
	 */
	mapping(string => Entity.Proposal) public proposals;
	mapping(string => bool) public uniqueStringRegistry;

	/**
	 * @dev Get proposal items and options
	 * @param id: id of the proposal
	 */
	function getProposalItemsAndOptions(string memory id)
		external
		view
		returns (Entity.SwapItem[] memory, Entity.SwapOption[] memory)
	{
		return (proposals[id].offeredItems, proposals[id].swapOptions);
	}

	/**
	 * @dev Configure swap registry
	 * @param _maxAllowedItems: maximum amount of allowed items
	 * @param _maxAllowedOptions: maximum amount of allowed options
	 * @param _whitelistedItemAddresses: whitelisted addresses
	 * @param _blackListedItemAddresses: blacklisted addresses
	 */
	function configure(
		uint256 _maxAllowedItems,
		uint256 _maxAllowedOptions,
		address[] memory _whitelistedItemAddresses,
		address[] memory _blackListedItemAddresses
	) external onlyOwner whenNotPaused {
		/**
		 * @dev Configure values
		 */
		maxAllowedItems = _maxAllowedItems;
		maxAllowedOptions = _maxAllowedOptions;

		/**
		 * @dev Whitelisting addresses
		 */
		for (uint256 i = 0; i < _whitelistedItemAddresses.length; i++) {
			whitelistedAddresses[_whitelistedItemAddresses[i]] = true;
		}

		/**
		 * @dev Blacklisted addresses
		 */
		for (uint256 i = 0; i < _blackListedItemAddresses.length; i++) {
			whitelistedAddresses[_blackListedItemAddresses[i]] = false;
		}
	}

	/**
	 * @dev Create proposal and deposit items
	 * @param id: proposal id
	 * @param swapItemsData: swap item list to be passed into proposal creation
	 * @param swapOptionsData: swap option list to be passed into proposal creation
	 * @param expiredAt: expiry date of the proposal
	 */
	function createProposal(
		string memory id,
		Params.SwapItemParams[] memory swapItemsData,
		Params.SwapOptionParams[] memory swapOptionsData,
		uint256 expiredAt
	) external whenNotPaused {
		/**
		 * @dev Avoid duplicated proposal id to be recorded in.
		 */
		assert(bytes(proposals[id].id).length == 0);

		/**
		 * @dev Must be unique id
		 */
		assert(uniqueStringRegistry[id] == false);

		/**
		 * @dev Require constraints
		 */
		assert(swapOptionsData.length <= maxAllowedOptions);
		assert(swapItemsData.length <= maxAllowedItems);
		assert(expiredAt > block.timestamp);

		/**
		 * @dev Assign proposal
		 */
		uniqueStringRegistry[id] = true;
		proposals[id].id = id;
		proposals[id].expiredAt = expiredAt;
		proposals[id].status = Entity.ProposalStatus.Deposited;
		proposals[id].owner = msg.sender;

		/**
		 * @dev Populate data
		 */
		for (uint256 i = 0; i < swapOptionsData.length; i++) {
			Entity.SwapOption storage option = proposals[id].swapOptions.push();
			option.id = swapOptionsData[i].id;

			for (
				uint256 j = 0;
				j < swapOptionsData[i].askingItems.length;
				j++
			) {
				Entity.SwapItem storage item = option.askingItems.push();

				item.id = swapOptionsData[i].askingItems[j].id;
				item.contractAddress = swapOptionsData[i]
					.askingItems[j]
					.contractAddress;
				item.itemType = swapOptionsData[i].askingItems[j].itemType;
				item.tokenId = swapOptionsData[i].askingItems[j].tokenId;
				item.amount = swapOptionsData[i].askingItems[j].amount;
				item.status = Entity.SwapItemStatus.Created;
			}
		}

		/**
		 * @dev Populate data
		 */
		for (uint256 i = 0; i < swapItemsData.length; i++) {
			/**
			 * @dev Must be a whitelisted addresses
			 */
			assert(
				whitelistedAddresses[swapItemsData[i].contractAddress] == true
			);

			/**
			 * @dev Initialize empty struct
			 */
			Entity.SwapItem storage swapItem = proposals[id]
				.offeredItems
				.push();

			/**
			 * @dev Assign data
			 */
			swapItem.id = swapItemsData[i].id;
			swapItem.contractAddress = swapItemsData[i].contractAddress;
			swapItem.itemType = swapItemsData[i].itemType;
			swapItem.amount = swapItemsData[i].amount;
			swapItem.owner = msg.sender;
			swapItem.status = Entity.SwapItemStatus.Deposited;
			swapItem.tokenId = swapItemsData[i].tokenId;
		}

		/**
		 * @dev Transfer items from user address to contract
		 */
		transferSwapItems(
			proposals[id].offeredItems,
			msg.sender,
			address(this),
			Entity.SwapItemStatus.Deposited
		);
	}

	/**
	 * @dev Fulfill proposal
	 * @param proposalId: the proposal id that targeted to
	 * @param optionId: the option id that user wants to fulfil with
	 */
	function fulfillProposal(string memory proposalId, string memory optionId)
		external
		whenNotPaused
	{
		/**
		 * @dev Must be an existed proposal
		 */
		assert(bytes(proposals[proposalId].id).length > 0);

		/**
		 * @dev The proposal must be at deposited phase.
		 */
		assert(proposals[proposalId].status == Entity.ProposalStatus.Deposited);

		/**
		 * @dev The proposal must be still in time window.
		 */
		assert(proposals[proposalId].expiredAt <= block.timestamp);

		/**
		 * @dev Adjust proposal value.
		 */
		proposals[proposalId].fulfilledBy = msg.sender;
		proposals[proposalId].fulfilledByOptionId = optionId;
		proposals[proposalId].status = Entity.ProposalStatus.Redeemed;

		/**
		 * @dev Find the proposal
		 */
		uint256 index = maxAllowedItems + 1;

		for (uint256 i = 0; i < proposals[proposalId].swapOptions.length; i++) {
			Entity.Proposal memory _proposal = proposals[proposalId];
			Entity.SwapOption memory _option = _proposal.swapOptions[i];
			string memory _optionId = _option.id;

			if (areStringsEqual(_optionId, optionId)) {
				index = i;
				break;
			}
		}

		/**
		 * @dev Check for constraints
		 */
		assert(index != maxAllowedItems + 1);

		/**
		 * @dev Binding option
		 */
		Entity.SwapOption storage option = proposals[proposalId].swapOptions[
			index
		];

		/**
		 * @dev Check for constraints
		 */
		assert(bytes(proposals[proposalId].swapOptions[index].id).length > 0);
		assert(option.askingItems.length <= maxAllowedItems);

		/**
		 * @dev Transfer assets to owner
		 */
		transferSwapItems(
			option.askingItems,
			msg.sender,
			address(proposals[proposalId].owner),
			Entity.SwapItemStatus.Redeemed
		);

		/**
		 * @dev And then redeem items
		 */
		transferSwapItems(
			proposals[proposalId].offeredItems,
			address(this),
			msg.sender,
			Entity.SwapItemStatus.Redeemed
		);
	}

	/**
	 * @dev Cancel proposal and withdraw assets
	 * @param proposalId: proposal id that was targeted
	 */
	function cancelProposal(string memory proposalId) external whenNotPaused {
		/**
		 * @dev Must be an existed proposal
		 */
		assert(bytes(proposals[proposalId].id).length > 0);

		/**
		 * @dev The proposal must be at deposited phase.
		 */
		assert(proposals[proposalId].owner == msg.sender);

		/**
		 * @dev The proposal must be at deposited phase.
		 */
		assert(proposals[proposalId].status == Entity.ProposalStatus.Deposited);

		/**
		 * @dev Modify value
		 */
		proposals[proposalId].status = Entity.ProposalStatus.Withdrawn;

		/**
		 * @dev Withdraw items
		 */
		transferSwapItems(
			proposals[proposalId].offeredItems,
			address(this),
			msg.sender,
			Entity.SwapItemStatus.Withdrawn
		);
	}

	function transferSwapItems(
		Entity.SwapItem[] storage items,
		address from,
		address to,
		Entity.SwapItemStatus remark
	) private {
		/**
		 * @dev And then withdraw items
		 */
		for (uint256 i = 0; i < items.length; i++) {
			/**
			 * @dev Must be a whitelisted addresses
			 */
			assert(whitelistedAddresses[items[i].contractAddress] == true);

			/**
			 * @dev Change to withdrawn
			 */
			items[i].status = remark;

			/**
			 * @dev withdraw ERC721 assets
			 */
			if (items[i].itemType == Entity.SwapItemType.Nft) {
				items[i].amount = 1;

				/**
				 * @dev withdraw
				 */
				IERC721(items[i].contractAddress).safeTransferFrom(
					from,
					to,
					items[i].tokenId
				);
			}

			/**
			 * @dev withdraw ERC20 assets
			 */
			if (items[i].itemType == Entity.SwapItemType.Currency) {
				items[i].tokenId = 0;
				/**
				 * @dev withdraw
				 */
				assert(
					IERC20(items[i].contractAddress).transferFrom(
						from,
						to,
						items[i].amount
					)
				);
			}
		}
	}

	/**
	 * @dev Utility function
	 */
	function areStringsEqual(string memory s1, string memory s2)
		private
		pure
		returns (bool)
	{
		return
			keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
	}

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize() public initializer {
		__Pausable_init();
		__Ownable_init();
	}

	function pause() public onlyOwner {
		_pause();
	}

	function unpause() public onlyOwner {
		_unpause();
	}

	function onERC721Received(
		address,
		address,
		uint256,
		bytes calldata
	) external pure returns (bytes4) {
		return IERC721Receiver.onERC721Received.selector;
	}
}
