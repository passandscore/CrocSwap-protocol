// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.8.4;

import '../libraries/Directives.sol';
import '../libraries/Encoding.sol';
import '../libraries/TokenFlow.sol';
import '../libraries/PriceGrid.sol';
import '../mixins/MarketSequencer.sol';
import '../mixins/SettleLayer.sol';
import '../mixins/PoolRegistry.sol';
import '../mixins/OracleHist.sol';
import '../mixins/MarketSequencer.sol';
import '../mixins/ProtocolAccount.sol';
import '../mixins/ColdInjector.sol';

import "hardhat/console.sol";

contract WarmPath is MarketSequencer, SettleLayer, PoolRegistry, ProtocolAccount {

    using SafeCast for uint128;
    using TokenFlow for TokenFlow.PairSeq;
    using CurveMath for CurveMath.CurveState;
    using Chaining for Chaining.PairFlow;

    function tradeWarm (bytes calldata input) public {
        (uint8 code, address base, address quote, uint24 poolIdx,
         int24 bidTick, int24 askTick, uint128 liq) =
            abi.decode(input, (uint8,address,address,uint24,int24,int24,uint128));

        if (code == 1) {
            mint(base, quote, poolIdx, bidTick, askTick, liq);
        } else if (code == 2) {
            burn(base, quote, poolIdx, bidTick, askTick, liq);
        } else if (code == 3) {
            mint(base, quote, poolIdx, liq);
        } else if (code == 4) {
            burn(base, quote, poolIdx, liq);
        }

    }
    
    function mint (address base, address quote,
                   uint24 poolIdx, int24 bidTick, int24 askTick, uint128 liq) internal {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        (int128 baseFlow, int128 quoteFlow) =
            mintOverPool(bidTick, askTick, liq, pool);
        settlePairFlow(base, quote, baseFlow, quoteFlow);
    }

    function burn (address base, address quote,
                   uint24 poolIdx, int24 bidTick, int24 askTick, uint128 liq) internal {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        (int128 baseFlow, int128 quoteFlow) =
            burnOverPool(bidTick, askTick, liq, pool);
        settlePairFlow(base, quote, baseFlow, quoteFlow);
    }


    function mint (address base, address quote,
                       uint24 poolIdx, uint128 liq) internal {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        (int128 baseFlow, int128 quoteFlow) =
            mintOverPool(liq, pool);
        settlePairFlow(base, quote, baseFlow, quoteFlow);
    }

    function burn (address base, address quote,
                   uint24 poolIdx, uint128 liq) internal {
        PoolSpecs.PoolCursor memory pool = queryPool(base, quote, poolIdx);
        (int128 baseFlow, int128 quoteFlow) =
            burnOverPool(liq, pool);
        settlePairFlow(base, quote, baseFlow, quoteFlow);
    }

    function settlePairFlow (address base, address quote,
                             int128 baseFlow, int128 quoteFlow) internal {
        Directives.SettlementChannel memory settle;
        settle.limitQty_ = type(int128).max;
        settle.token_ = base;
        settleFlat(msg.sender, baseFlow, settle, false);

        settle.token_ = quote;
        settleFlat(msg.sender, quoteFlow, settle, false);        
    }
}