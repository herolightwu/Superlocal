// SPDX-License-Identifier: ISC



pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "hardhat/console.sol";

contract Mayorship is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 private constant MAX = ~uint256(0);
    uint public constant MAX_SUPPLY = MAX;      // max mintable count
    uint public constant PRICE = 0.07 ether;    // price per each nft mint
    uint public constant MAX_PER_MINT = 1;  // allow mint one NFT at one time

    mapping(uint256 => uint) private _token_place;  //token ID -> place ID  
    mapping(uint => uint256) private _place_token;  // place ID -> token ID
    mapping(uint => bool) private _occupied_place;  // place ID -> token ID

    string public baseTokenURI;
    string public _contractURI;
    string private hiddenMetadataUri = "";
    string private uriSuffix = ".json";
    bool private revealed;

    /// @dev
    event Mint(address);

    constructor(string memory baseURI) ERC721("Mayorship", "MAYORSHIP") {
        setBaseURI(baseURI);
    }

    /// @dev get the Place id by token id
    /// @param _tokenId token id of Mayorship
    function getPlaceIdByToken(uint256 _tokenId) public view returns (uint){
        return _token_place[_tokenId];
    }

    /// @dev get the token id by place id
    /// @param _placeId place id of Mayorship
    function getTokenIdByPlace(uint _placeId) public view returns (uint256){
        return _place_token[_placeId];
    }

    /// @dev set hiddenMetadataUri
    /// @param _hiddenMetadataUri default uri for Metadata
    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    /// @dev set uriSuffix
    /// @param _uriSuffix suffix of uri for Metadata
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    /// @dev mint function for owner
    function reserveMint(uint _placeId) public onlyOwner {
        uint totalMinted = _tokenIds.current();

        require(_occupied_place[_placeId] == false, "The place was occupied already!");
        require(totalMinted.add(1) < MAX_SUPPLY, "Not enough NFTs left to reserve");

        _mintSingleNFT(_placeId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
        if (bytes(_baseTokenURI).length > 0){
            revealed = true;
        } else {
            revealed = false;
        }
    }

    /// @dev payable mint fucntion
    function mint(uint _placeId) public payable {
        uint totalMinted = _tokenIds.current();

        require(_occupied_place[_placeId] == false, "The place was occupied already!");
        require(totalMinted.add(1) <= MAX_SUPPLY, "Not enough NFTs left!");
        require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");

        _mintSingleNFT(_placeId);
    }

    /// @dev function to mint a NFT
    function _mintSingleNFT(uint _placeId) private {
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment();
        
        _token_place[newTokenID] = _placeId;
        _place_token[_placeId] = newTokenID;
        _occupied_place[_placeId] = true;

        emit Mint(msg.sender);
    }

    function tokensOfOwner(address _owner) external view returns (uint[] memory) {

        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);

        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /// @dev withdraw collected ethers
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // Opensea Automatic Collection Data

    /// @dev set _contractURI
    /// @param _contURI uri for this json data
    function setContactURI(string memory _contURI) external onlyOwner{
        _contractURI = _contURI;
    }

    function contractURI() public view returns (string memory) {
        // Following link must return this json data.
        // {
        //   "name": "OpenSea Creatures",
        //   "description": "OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.",
        //   "image": "external-link-url/image.png",
        //   "external_link": "external-link-url",
        //   "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
        //   "fee_recipient": "0xA97F337c39cccE66adfeCB2BF99C1DdC54C2D721" # Where seller fees will be paid to.
        // }

        return _contractURI;
    }

   /** RENDER */
    /// @dev return the uri for token id
    /// @param tokenId token id
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {

        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

}