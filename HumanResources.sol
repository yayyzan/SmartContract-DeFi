// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;
import "./IHumanResources.sol";


abstract contract HumanResources is IHumanResources {

   

    enum preferredPay {USDC, ETH}

    struct Employee{
        uint256 weeklyUsdSalary;
        uint256 employedSince;
        uint256 terminatedAt;
        uint256 accumulated;
        uint256 lastWithdrawalStamp;
        preferredPay preference;
    }

    address public immutable hrManagerAddress; 
    mapping(address => Employee) private employeeMap;
    address[] public employeeAddresses;
    uint256 employeeCount;

    constructor(address _hrManager){
        hrManagerAddress = _hrManager; 
        swapRouter = ISwapRouter(ROUTER);
        usdc = IERC(USDC);
    }

    modifier onlyHrManager(){
        require(msg.sender == hrManagerAddress, NotAuthorized());
        _;
    }

    modifier onlyEmployee(){
        require(employeeMap[msg.sender].employedSince != 0, NotAuthorized());
    }

    function salaryAvailable (address employee) external view returns (uint256){
        return ((block.timestamp - employeeMap[employee].lastWithdrawalStamp) / 1 weeks) * employeeMap[employee].weeklyUsdSalary;
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



    function registerEmployee (address employee, uint256 weeklyUsdSalary) onlyHrManager external {
        uint256 checkEmployee = employeeMap[employee].employedSince;
        if (checkEmployee == 0){
            Employee memory newEmployee = Employee(weeklyUsdSalary, block.timestamp, 0, 0, block.timestamp, preferredPay.USDC);
            employeeMap[employee] = newEmployee;
            employeeAddresses.push(employee);
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
        employeeMap[employee].accumulated = ((block.timestamp - employeeMap[employee].lastWithdrawalStamp) / 1 weeks) * employeeMap[employee].weeklyUsdSalary;
        emit EmployeeTerminated(employee);
    }



    
}
