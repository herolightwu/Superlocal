// SPDX-License-Identifier: ISC

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Local is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 0;            // total balance
    uint256 private _rTotal = MAX;          // reset later
    uint256 private _tFeeTotal;

    // _name, _symbol, _decimal is constant
    string private constant _name = "Local";
    string private constant _symbol = "LOCAL";
    uint8 private constant _decimals = 9;

    uint256 public constant _maxTotal = 500000000 * 10**6 * 10**9;
    uint256 public constant PRICE = 0.0001 ether;
    uint256 public _maxTxAmount = 200 * 10**9;  //max amount per one transaction

    /**
     * @dev
     */
    uint256 public _royaltyFee = 5;
    uint256 private _previousRoyaltyFee = _royaltyFee;
    
    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;

    bool public tradingEnabled = false;

    uint256 private constant numTokensToWithdraw = 100 * 10**9;

    // We will set the _rTotal value when any customer mints the token at first.
    // For this, we need to set the initialized rate.
    // If we don't set this, while calculating, _rTotal or current rate is overflow.
    uint256 private _initRate = MAX.div(_maxTotal);

    // check first mint only
    bool private _bInitMint = false;

    /// --- Events
    event Mint(address, uint256);
    event RewardMint(address, uint256);
    event TaxFeePercentUpdated(uint256);
    event RoyaltyFeePercentUpdated(uint256);
    event WithdrawToken(uint256);
    event MaxTxAmountUpdated(uint256);


    modifier isGreaterThanZero(uint256 value) {
        require(value > 0, "Amount must be greater than zero");
        _;
    }

    constructor() {
        // _rOwned[_msgSender()] = _rTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;        
    }

    function mint(uint256 amount) public payable isGreaterThanZero(amount) {
        
        require(_tTotal.add(amount) <= _maxTotal, "Mint amount is exceeded");
        require(msg.value.mul(uint256(10)**uint256(_decimals)) >= PRICE.mul(amount), "Not enough ether to mint tokens");
        require(amount <= _maxTxAmount, "One mint amount exceeds the maxTxAmount");

        mintToken(msg.sender, amount);

        emit Mint(msg.sender, amount);
    }

    function mintToken(address recipient, uint256 amount) private {
        uint256 rAmount;
        
        if (_bInitMint == false) {
            // the first setting for _rTotal by the first mint amount and initialized rate.
            _tTotal = amount;
            _rTotal = _initRate.mul(amount);
            _bInitMint = true;
        } else {
            // the calculation for _tTotal and _rTotal while minting.
            rAmount = _rTotal.div(_tTotal).mul(amount);
            _tTotal = _tTotal.add(amount);
            _rTotal = _rTotal.add(rAmount);
        }

        rAmount = reflectionFromToken(amount, false);
        _rOwned[address(this)] = _rOwned[address(this)].add(rAmount);

        // console.log("_B rAmount:", rAmount);
        // console.log("_B  rTotal:", _rTotal);

        // transfer from this to recipient
        _transfer(address(this), recipient, amount);
        
    }

    function rewardMint(address recipient, uint256 amount) public onlyOwner isGreaterThanZero(amount){
        require(_tTotal.add(amount) <= _maxTotal, "Mint amount is exceeded");
        require(amount <= _maxTxAmount, "One mint amount exceeds the maxTxAmount.");

        if (balanceOf(address(this)) >= amount){
            _transfer(address(this), recipient, amount);            
        } else {
            mintToken(recipient, amount);
        }
        
        emit RewardMint(recipient, amount);
    }

    /// @dev withdraw the ethers from token to owner
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    } 

    /// @dev transfer the tokens from address(this) to Owner.
    function withdrawToken() public onlyOwner{
        uint256 balance = balanceOf(address(this));
        require(balance >= numTokensToWithdraw, "Balance is not enough to withdraw");
        _transfer(address(this), owner(), balance);

        emit WithdrawToken(balance);
    }   

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        if (_tTotal == 0) return 0;
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender) public view override returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(_tTotal > 0, "Token balance is 0");
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
        // console.log("rAmount", rAmount);
        // console.log("_rTotal", _rTotal);
        require(_tTotal > 0, "Token balance is 0");
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        uint256 currentRate;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                // Variable _rOwned not updated
                currentRate = _getRate();
                _rOwned[account] = _tOwned[account].mul(currentRate);

                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tRoyalty
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeRoyalty(tRoyalty);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    /// @dev set the TaxFee
    /// @param taxFee new taxFee (0~100)
    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
        emit TaxFeePercentUpdated(taxFee);
    }

    /// @dev set the RoyaltyFee
    /// @param royaltyFee new RoyaltyFee (0~100)
    function setRoyaltyFeePercent(uint256 royaltyFee) external onlyOwner {
        _royaltyFee = royaltyFee;
        emit RoyaltyFeePercentUpdated(royaltyFee);
    }

    /// @dev set the max amount for one transaction
    /// @param maxTxAmount new maxTxAmount
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
        emit MaxTxAmountUpdated(maxTxAmount);
    }

    /// @dev return the TaxFee (0~100)
    function getTaxFeePercent() public view returns (uint256) {
        return _taxFee;
    }
    
    /// @dev return the RoyaltyFee (0~100)
    function getRoyaltyFeePercent() public view returns (uint256) {
        return _royaltyFee;
    }

    /// @dev return the max amount for one transaction
    function getMaxTxAmount() public view returns (uint256) {
        return _maxTxAmount;
    }

    /**
     * @dev Allow Intimate to be traded
     */
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
    }

    // important to receive ETH
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tFee, uint256 tRoyalty) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tRoyalty, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tRoyalty);
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tRoyalty = calculateRoyaltyFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tRoyalty);
        return (tTransferAmount, tFee, tRoyalty);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tRoyalty,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rRoyalty = tRoyalty.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rRoyalty);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeRoyalty(uint256 tRoyalty) private {
        uint256 currentRate = _getRate();
        uint256 rRoyalty = tRoyalty.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rRoyalty);
        if (_isExcluded[address(this)]) _tOwned[address(this)] = _tOwned[address(this)].add(tRoyalty);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateRoyaltyFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_royaltyFee).div(10**2);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _royaltyFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousRoyaltyFee = _royaltyFee;

        _taxFee = 0;
        _royaltyFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _royaltyFee = _previousRoyaltyFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address _owner,
        address spender,
        uint256 amount
    ) private {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private isGreaterThanZero(amount) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        if (from != owner() && !tradingEnabled) {
            require(tradingEnabled, "Trading is not enabled yet");
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // transfer amount, it will take tax, Royalty fee
        _tokenTransfer(from, to, amount, takeFee);
    }
    
    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tRoyalty
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeRoyalty(tRoyalty);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tRoyalty
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeRoyalty(tRoyalty);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tRoyalty
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeRoyalty(tRoyalty);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

}