// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;
import "./IHumanResources.sol";
import "./node_modules/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "./node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import './node_modules/@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import './node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract HumanResources is IHumanResources {

    address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address ROUTER = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;
    address WETH = 0x4200000000000000000000000000000000000006;
    address CHAINLINK = 0x13e3Ee699D1909E989722E753853AE30b17e08c5;

    uint256 USDC_D = 1e12;

    struct Employee{
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 accumulated;
        uint256 lastWithdrawalStamp;
        bool preferenceIsEth;
    }

    address public immutable hrManagerAddress; 
    mapping(address => Employee) private employeeMap;
    uint256 employeeCount;

    ISwapRouter swapRouter;
    IERC20 usdc;
    AggregatorV3Interface exchange;

    constructor(address _hrManager){
        hrManagerAddress = _hrManager; 
        swapRouter = ISwapRouter(ROUTER);
        usdc = IERC20(USDC);
        exchange = AggregatorV3Interface(CHAINLINK);
    }

    modifier onlyHrManager(){
        require(msg.sender == hrManagerAddress, NotAuthorized());
        _;
    }

    modifier onlyEmployee(){
        require(employeeMap[msg.sender].employedSince != 0, NotAuthorized());
        _;
    }

    function ethPrice(uint256 usdcAmount) internal view returns (uint256) {
        (, int256 price, , ,) = exchange.latestRoundData();
        return (usdcAmount * 1e18) / uint256(price);
    }

    function computeSalary(address employee) internal view returns (uint256){
        return ((block.timestamp - employeeMap[employee].lastWithdrawalStamp) / 1 weeks) * employeeMap[employee].weeklyUsdSalary;
    }

    function salaryAvailable (address employee) external view returns (uint256){
        uint256 pay = computeSalary(employee);
        if(employeeMap[employee].preferenceIsEth == true){
            return ethPrice(pay);
        } else {
            return pay/USDC_D;
        }
        
    }

    function hrManager() external view returns (address){
        return hrManagerAddress;
    }

    function getActiveEmployeeCount() external view returns(uint256){
        return employeeCount;
    }

    function getEmployeeInfo(address employee) external view returns(uint256, uint256, uint256){
        Employee memory employeeInfo = employeeMap[employee];
        return (employeeInfo.weeklyUsdSalary, employeeInfo.employedSince, employeeInfo.terminatedAt);
    }

    function swapUSDCForEth(uint256 usdcAmount, uint256 slippage) private returns (uint256) {
        usdc.approve(address(swapRouter), usdcAmount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: WETH,
            fee: 3000, 
            recipient: address(this),
            deadline: block.timestamp + 30,
            amountIn: usdcAmount,
            amountOutMinimum: slippage,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        return amountOut;
    } 

    function registerEmployee (address employee, uint256 weeklyUsdSalary) onlyHrManager external {
        uint256 checkEmployee = employeeMap[employee].employedSince;
        if (checkEmployee == 0){
            Employee memory newEmployee = Employee(weeklyUsdSalary, block.timestamp, 0, 0, block.timestamp, false);
            employeeMap[employee] = newEmployee;
            employeeCount += 1;
            emit EmployeeRegistered(employee, weeklyUsdSalary);
        }
        else {
            revert EmployeeAlreadyRegistered();
        }
    }

    function terminateEmployee (address employee) onlyHrManager external {
        if(employeeMap[employee].employedSince  == 0){
            revert EmployeeNotRegistered();
        }
        employeeMap[employee].terminatedAt = block.timestamp;
        employeeMap[employee].employedSince = 0;
        employeeMap[employee].weeklyUsdSalary = 0;
        employeeCount -= 1;
        employeeMap[employee].accumulated = computeSalary(employee);
        emit EmployeeTerminated(employee);
    }

    function withdrawSalary() onlyEmployee external {
        bool preferredMethod = employeeMap[msg.sender].preferenceIsEth;
        uint256 salary = employeeMap[msg.sender].accumulated + computeSalary(msg.sender);
        if(preferredMethod){
            uint256 eth = swapUSDCForEth(salary, 2);
            TransferHelper.safeTransferETH(msg.sender, eth);
        } else {
            TransferHelper.safeTransferFrom(USDC, address(this), msg.sender, salary/USDC_D);
        }
        employeeMap[msg.sender].accumulated = 0;
        employeeMap[msg.sender].lastWithdrawalStamp = block.timestamp;
        emit SalaryWithdrawn(msg.sender, preferredMethod, salary);
    }

    function switchCurrency() onlyEmployee external {
        this.withdrawSalary();
        employeeMap[msg.sender].preferenceIsEth = !employeeMap[msg.sender].preferenceIsEth;
        emit CurrencySwitched(msg.sender, employeeMap[msg.sender].preferenceIsEth);
    }
    
}
