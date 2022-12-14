//SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IFakeNFTMarketplace {
     function purchase(uint256 _tokenId) external payable;

     function getPrice() external view returns (uint256);

     function available(uint256 _tokenId) external view returns (bool);
}

interface ICryptoDevsNFT {
    function balanceOf(address owner) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract CryptoDevsDAO is Ownable {

    enum Vote {
        YAY,
        NAY
    }

    struct Proposal {
        // The NFT to Buy from the secondary marketplace
        uint256 nftTokenId;
        // when does voting end
        uint256 deadline;
        uint256 yayvotes;
        uint256 nayvotes;
        bool executed;
        mapping(uint256 => bool) voters; 
    }

    // Proposal ID => Proposal
    mapping(uint256 => Proposal) public proposals;
    // total number of Proposals
    uint256 public numProposals;
    
    // Reference to the Contract, 
    // get initialized in the constructor
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    // when first created the contract get sends some eth
    // which will be the first funds for the DAO
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");   
        _;
    }

    modifier activeProposalOnly(uint256 proposalId) {
        require(proposals[proposalId].deadline > block.timestamp, "PROPOSAL_INACTIVE");
        _;
    }

    modifier inactiveProposalOnly(uint256 proposalId) {
        require(proposals[proposalId].deadline <= block.timestamp, "PROPOSAL_ACTIVE");
        require(proposals[proposalId].executed == false, "ALREADY_EXECUTED");
        _;
    }

    //create a proposal - member only
    // _nftTokenId refers to the NFT you want to buy "FakeMarketPlace"
    // returns ID of newly created proposal
    function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");

        // the new Proposal gets stored in the current index
        // of the proposals mapping()
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        // ID is current index, but it got incremented
        // so we must return "old" numProposals value
        return numProposals - 1;
    }

    // vote ona proposal - member only
    function voteOnProposal(uint256 proposalId, Vote vote) external nftHolderOnly activeProposalOnly(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes;

        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayvotes += numVotes;
        } else {
            proposal.nayvotes += numVotes;
        }
    }

    // execute the proposal - member only
    function executeProposal(uint256 proposalId) external nftHolderOnly inactiveProposalOnly(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        // did the proposal pass ?
        if (proposal.yayvotes > proposal.nayvotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }

        proposal.executed = true;
    }

    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
    fallback() external payable {}
}