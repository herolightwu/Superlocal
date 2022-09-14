// SPDX-License-Identifier: ISC

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./StampNFT.sol";
import "../tokens/Local.sol";

import "hardhat/console.sol";

contract PassportNFT is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 private constant MAX = ~uint256(0);
    uint public constant MAX_SUPPLY = MAX;      // max mintable count
    uint public constant PRICE = 0.025 ether;   // $25 USD , price per each nft mint
    uint public constant MAX_PER_MINT = 1;       // 1 mintable at once
    uint256 private constant MAX_DEADLINE = 10 * 24 * 60 * 60;  // 10 days
    uint private constant ONE_DAY = 24 * 60 * 60;

    
    struct Passport{
        uint level;     // level value 0..25
        uint luck;      // luck value  0..100
        uint256 renewal;   // expire timestamp
        uint256[] stamp_arr;  // Stamp NFT tokenID array
        string image;    // image url
    }

    /**
     * @dev
     */
    uint public _maxApplyStamp = 20;

    /// --- Events
    event MaxApplyStampUpdated(uint);
    event StampApplied(uint256, uint256);
    event SetPassportImage(uint256, string);
    event SetPassportRenewal(uint256, uint256);
    event Mint(address);
    event LevelUpPassport(address, uint);

    mapping(uint256 => Passport) private _properties;   // property for each NFT token 
    mapping(uint => uint) private _fiat_fee;            // price to level up the passport on each level

    string public baseTokenURI;
    string public _contractURI;
    string private hiddenMetadataUri = "";
    string private uriSuffix = ".json";
    bool private revealed;

    /// @dev StampNFT token contract
    StampNFT _stamp;
    /// @dev Local token contract
    Local _local;

    constructor(string memory baseURI, address stamp, address local) ERC721("PassportNFT", "PASSPORTNFT") {
        setBaseURI(baseURI);
        _stamp = StampNFT(payable(stamp));
        _local = Local(payable(local));
        // _fiat_fee
        _fiat_fee[2] = PRICE;
        _fiat_fee[5] = PRICE;
        _fiat_fee[10] = PRICE;
        _fiat_fee[15] = PRICE;
        _fiat_fee[20] = PRICE.mul(2);
    }

    /// @dev get the appliable stamp count
    /// 
    function getMaxApplyStamp() public view returns (uint) {
         return _maxApplyStamp; 
    }

    /// @dev Set the appliable stamp count
    /// @param maxApplyStamp the appliable stamp count
    function setMaxApplyStamp(uint maxApplyStamp) external onlyOwner {
        _maxApplyStamp = maxApplyStamp;
        emit MaxApplyStampUpdated(maxApplyStamp);
    }

    /// @dev Return the level of the Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    function getPassportLevel(uint256 _tokenId) public view returns (uint){
        require (_properties[_tokenId].renewal >= block.timestamp, "Passport expired");
        return _properties[_tokenId].level;
    }

    /// @dev level up the level of the Passport by Passport id
    /// @param _tokenId     Token ID of the Passport
    /// will add to check the amount of user's local token later
    function levelUpPassport(uint256 _tokenId) public payable {
        require(ownerOf(_tokenId) != address(0), "Holder does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Holder only can level up");
        require(_properties[_tokenId].renewal >= block.timestamp, "Passport expired");
        
        uint cur_level = _properties[_tokenId].level;
        uint new_level = cur_level.add(1);        
        require(_properties[_tokenId].stamp_arr.length >= new_level, "Applied stamps does not enough");
        require(msg.value >= _fiat_fee[new_level], "Not enough ether to level up passport");

        /// check the amount of user's local token
        /// calculate the needed amount to level up 
        uint256 half_level = cur_level.div(2);
        uint256 local_amount = cur_level.add(cur_level**2).add(2**half_level);
        local_amount = local_amount.mul(50).mul(10**9);
        /// check the token condition to level up 
        uint256 token_balance = _local.balanceOf(msg.sender);
        require(token_balance >= local_amount, "Not enough tokens to level up passport");
        
        _local.transferFrom(msg.sender, address(_local), local_amount);

        _properties[_tokenId].level = new_level;

        emit LevelUpPassport(msg.sender, new_level);
    }

    /// @dev Return the luck of the Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    function getPassportLuck(uint256 _tokenId) public view returns (uint){
        require (_properties[_tokenId].renewal >= block.timestamp, "Passport expired");
        return _properties[_tokenId].luck;
    }

    /// @dev set the luck of the Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    /// @param _luck    new luck value (0..100) of the Passport
    function setPassportLuck(uint256 _tokenId, uint _luck) public onlyOwner{
        require(_properties[_tokenId].renewal >= block.timestamp, "Passport expired");
        require( _luck >= 0  && _luck <= 100, "Luck value is bigger than 0, smaller than 100");
        _properties[_tokenId].luck = _luck;
    }

    /// @dev Return the applied stamps on Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    function getPassportStamps(uint256 _tokenId) public view returns (uint256[] memory){
        return _properties[_tokenId].stamp_arr;
    }

    /// @dev apply Stamp NFT to passport
    /// @param _tokenId Token ID of the Passport
    /// @param _stampId Token ID of the Stamp
    function setStamp(uint256 _tokenId, uint256 _stampId) public onlyOwner {
        require(_properties[_tokenId].stamp_arr.length < _maxApplyStamp, "Applied Stamp amount is exceed.");
        
        require(ownerOf(_tokenId) != address(0) && _stamp.ownerOf(_stampId) != address(0), "Holders does not exist");
        require(ownerOf(_tokenId) == _stamp.ownerOf(_stampId), "Passport and Stamp has difference holders");
        require(checkAppliedStamp(_tokenId, _stampId) == false, "Stamp was applied already");
        _properties[_tokenId].stamp_arr.push(_stampId);

        emit StampApplied(_tokenId, _stampId);
    }

    function checkAppliedStamp(uint256 _tokenid, uint256 _stampId) private view returns (bool){
        for (uint i = 0; i < _properties[_tokenid].stamp_arr.length; i++){
            if (_properties[_tokenid].stamp_arr[i] == _stampId){
                return true;
            }
        }
        return false;
    }
    
    /// @dev Return the count of the applied stamps on Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    function getAppliedStampCount(uint256 _tokenId) public view returns (uint256) {
        return _properties[_tokenId].stamp_arr.length;
    }

    /// @dev Return the image url of the Passport by id
    /// @param _tokenId Token ID of the PassportNFT
    function getPassportImage(uint256 _tokenId) public view returns (string memory) {
        return _properties[_tokenId].image;
    }

    /// @dev set the image url of the Passport by id
    /// @param _tokenId Token ID of the PassportNFT
    /// @param _imgUrl  New image path for the PassportNFT
    function setPassportImage(uint256 _tokenId, string memory _imgUrl) public onlyOwner {
        _properties[_tokenId].image = _imgUrl;
        emit SetPassportImage(_tokenId, _imgUrl);
    }

    /// @dev Return the decay degree (as 10..0)for available time (as seconds) of the Passport by Passport id
    ///      If renewal date is expired, return 0.
    /// @param _tokenId Token ID of the Passport
    function getPassportDecay(uint256 _tokenId) public view returns (uint256){
        require (_properties[_tokenId].renewal >= block.timestamp, "Passport expired");
        uint256 decay = _properties[_tokenId].renewal - block.timestamp;
        decay = decay.add(ONE_DAY);
        return decay.mul(10).div(MAX_DEADLINE);
    }

    /// @dev Set the available time (as seconds) of the Passport by Passport id
    /// @param _tokenId Token ID of the Passport
    /// @param _newRenewal new available timestamp of the Passport
    function setPassportRenwal(uint256 _tokenId, uint256 _newRenewal) public onlyOwner {
        require (_newRenewal > block.timestamp, "Renewal date is past");
        require (_properties[_tokenId].renewal < _newRenewal, "Not enough renewal date to reset");
        require (_newRenewal - block.timestamp <= MAX_DEADLINE, "Renewal date cannot over than 10 days");
        _properties[_tokenId].renewal = _newRenewal;

        emit SetPassportRenewal(_tokenId, _newRenewal);
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

    /// @dev non-payable mint function for owner only 
    ///     this function can mint one of Passport only at one time.    
    function reserveMint() public onlyOwner {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(1) < MAX_SUPPLY, "Not enough NFTs left to reserve");

        _mintSingleNFT();
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

    function mint() public payable {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(1) <= MAX_SUPPLY, "Not enough NFTs left!");
        require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");

        _mintSingleNFT();
    }

    function _mintSingleNFT() private {
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment();

        _properties[newTokenID] = Passport(0, 0, block.timestamp + MAX_DEADLINE, new uint256[](0), "");

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