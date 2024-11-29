// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./IHumanResources.sol";

interface IWETH {
    function withdraw(uint256 amount) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract HumanResources is IHumanResources, ReentrancyGuard {
    address private constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address private constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant WETH = 0x4200000000000000000000000000000000000006;
    address private constant CHAINLINK = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
    uint256 private constant USDC_DENOMINATOR = 1e12;
    uint256 private constant SLIPPAGE_PERCENTAGE = 2;

    struct Employee {
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 accumulated;
        uint256 lastWithdrawalStamp;
        bool preferenceIsEth;
    }

    address public immutable hrManagerAddress;
    mapping(address => Employee) private employeeMap;
    uint256 private employeeCount;

    ISwapRouter private immutable swapRouter;
    IERC20 private immutable usdc;
    IWETH private immutable weth;
    AggregatorV3Interface private immutable exchange;

    constructor(address _hrManager) {
        hrManagerAddress = _hrManager;
        swapRouter = ISwapRouter(ROUTER);
        usdc = IERC20(USDC);
        weth = IWETH(WETH);
        exchange = AggregatorV3Interface(CHAINLINK);
    }

    modifier onlyHrManager() {
        require(msg.sender == hrManagerAddress, NotAuthorized());
        _;
    }

    modifier mustBeRegistered() {
        require(
            employeeMap[msg.sender].employedSince != 0 || 
            employeeMap[msg.sender].terminatedAt != 0, 
            NotAuthorized()
        );
        _;
    }

    modifier mustBeActive() {
        require(
            employeeMap[msg.sender].employedSince != 0 && 
            employeeMap[msg.sender].terminatedAt == 0, 
            NotAuthorized()
        );
        _;
    }

    receive() external payable {}

    function convertUsdcToEthAmount(uint256 usdcAmount) private view returns (uint256) {
        (, int256 feedPrice, , , ) = exchange.latestRoundData();
        uint256 feedDecimals = exchange.decimals();
        uint256 price = uint256(feedPrice) * 10 ** (18 - feedDecimals);
        return (usdcAmount * 1e18) / uint256(price);
    }

    function calculateAccruedSalary(address employee) internal view returns (uint256) {
        return (
            (block.timestamp - employeeMap[employee].lastWithdrawalStamp) * 
            employeeMap[employee].weeklyUsdSalary
        ) / 1 weeks;
    }

    function salaryAvailable(address employee) external view returns (uint256) {
        Employee memory emp = employeeMap[employee];
        uint256 pay = calculateAccruedSalary(employee) + emp.accumulated;
        return emp.preferenceIsEth ? convertUsdcToEthAmount(pay) : pay / USDC_DENOMINATOR;
    }

    function hrManager() external view returns (address) {
        return hrManagerAddress;
    }

    function getActiveEmployeeCount() external view returns (uint256) {
        return employeeCount;
    }

    function getEmployeeInfo(address employee) external view returns (uint256, uint256, uint256) {
        Employee memory emp = employeeMap[employee];
        return (emp.weeklyUsdSalary, emp.employedSince, emp.terminatedAt);
    }

    function swapUSDCForEth(uint256 usdcAmount, uint256 slippagePercentage) private returns (uint256) {
        TransferHelper.safeApprove(USDC, address(swapRouter), usdcAmount);

        uint256 minimumEthOutput = convertUsdcToEthAmount(usdcAmount) * (100 - slippagePercentage) / 100;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: WETH,
            fee: 3000,  
            recipient: address(this),
            deadline: block.timestamp + 300,
            amountIn: usdcAmount,
            amountOutMinimum: minimumEthOutput,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    function registerEmployee(address employee, uint256 weeklyUsdSalary) 
        external 
        onlyHrManager 
    {
        Employee storage emp = employeeMap[employee];
        if (emp.employedSince == 0 || emp.terminatedAt != 0) {
            emp.weeklyUsdSalary = weeklyUsdSalary;
            emp.employedSince = block.timestamp;
            emp.terminatedAt = 0;
            emp.lastWithdrawalStamp = block.timestamp;
            emp.preferenceIsEth = false;
            employeeCount += 1;
            emit EmployeeRegistered(employee, weeklyUsdSalary);
        } else {
            revert EmployeeAlreadyRegistered();
        }
    }

    function terminateEmployee(address employee) 
        external 
        onlyHrManager 
    {
        Employee storage emp = employeeMap[employee];
        if (emp.employedSince == 0) {
            revert EmployeeNotRegistered();
        }
        
        emp.terminatedAt = block.timestamp;
        emp.accumulated = calculateAccruedSalary(employee);
        emp.lastWithdrawalStamp = 0;
        emp.weeklyUsdSalary = 0;
        employeeCount -= 1;
        
        emit EmployeeTerminated(employee);
    }

    function withdrawSalary() 
        external 
        mustBeRegistered 
        nonReentrant
    {
        Employee storage emp = employeeMap[msg.sender];
        uint256 salary = calculateAccruedSalary(msg.sender) + emp.accumulated;

        if (emp.preferenceIsEth) {
            uint256 ethAmount = swapUSDCForEth(salary / USDC_DENOMINATOR, SLIPPAGE_PERCENTAGE);
            weth.withdraw(ethAmount);
            TransferHelper.safeTransferETH(msg.sender, ethAmount);
        } else {
            TransferHelper.safeTransfer(USDC, msg.sender, salary / USDC_DENOMINATOR);
        }

        emp.accumulated = 0;
        emp.lastWithdrawalStamp = block.timestamp;

        emit SalaryWithdrawn(msg.sender, emp.preferenceIsEth, salary);
    }

    function switchCurrency() 
        external 
        mustBeActive 
        nonReentrant
    {
        Employee storage emp = employeeMap[msg.sender];
        uint256 salary = calculateAccruedSalary(msg.sender) + emp.accumulated;

        if (emp.preferenceIsEth) {
            uint256 ethAmount = swapUSDCForEth(salary / USDC_DENOMINATOR, SLIPPAGE_PERCENTAGE);
            weth.withdraw(ethAmount);
            payable(msg.sender).transfer(ethAmount);
        } else {
            usdc.transfer(msg.sender, salary / USDC_DENOMINATOR);
        }

        emp.accumulated = 0;
        emp.lastWithdrawalStamp = block.timestamp;
        emp.preferenceIsEth = !emp.preferenceIsEth;
        
        emit CurrencySwitched(msg.sender, emp.preferenceIsEth);
    }
}