import math

print("[Milestone1]")
print("--------------------------------------------")
'''
通过价格计算出相对应的 tick
'''
def price_to_tick(p):
    return math.floor(math.log(p, 1.0001))

ic = price_to_tick(5000)
il = price_to_tick(4545)
iu = price_to_tick(5500)
print("现价tick =", ic)
print("下界tick =", il)
print("上界tick =", iu)

'''
Uniswap 使用 Q64.96 来存储 √p,
在我们上面的计算中价格按照浮点数形式计算: 70.71, 67.42, 74.16,
我们需要将它们转换成 Q64.96 格式，只需要将这个数乘以 2**96.
'''
q96 = 2**96
def price_to_sqrtp(p):
    return int(math.sqrt(p) * q96)

sqrtp_cur = price_to_sqrtp(5000)
sqrtp_low = price_to_sqrtp(4545)
sqrtp_upp = price_to_sqrtp(5500)
print("sqrtp_cur =", sqrtp_cur)
print("sqrtp_low =", sqrtp_low)
print("sqrtp_upp =", sqrtp_upp)

'''
流动性数量计算
'''
def liquidity0(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return (amount * (pa * pb) / q96) / (pb - pa)

def liquidity1(amount, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return amount * q96 / (pb - pa)

amount_eth = 1 * 10**18    # 投入 1 个 ETH
amount_usdc = 5000 * 10**18 # 投入 5000 个 USDC
liq0 = liquidity0(amount_eth, sqrtp_cur, sqrtp_upp)
liq1 = liquidity1(amount_usdc, sqrtp_cur, sqrtp_low)
liq = int(min(liq0, liq1))
print("liq =", liq)

'''
重新计算 token 数量
'''
def calc_amount0(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * q96 * (pb - pa) / pa / pb)


def calc_amount1(liq, pa, pb):
    if pa > pb:
        pa, pb = pb, pa
    return int(liq * (pb - pa) / q96)

amount0 = calc_amount0(liq, sqrtp_upp, sqrtp_cur)
amount1 = calc_amount1(liq, sqrtp_low, sqrtp_cur)
(amount0, amount1)
print("amount0 =", amount0)
print("amount1 =", amount1)

amount_in = 42 * 10**18
price_diff = (amount_in * q96) // liq
price_next = sqrtp_cur + price_diff
print("New price:", (price_next / q96) ** 2)
print("New sqrtP:", price_next)
print("New tick:", price_to_tick((price_next / q96) ** 2))

amount_in = calc_amount1(liq, price_next, sqrtp_cur)
amount_out = calc_amount0(liq, price_next, sqrtp_cur)
print("USDC in:", amount_in / 1e18)
print("ETH out:", amount_out / 1e18)
print("--------------------------------------------")
print("[Milestone2]")
print("--------------------------------------------")
amount_in = 0.01337 * 10**18

print(f"Selling {amount_in/10**18} ETH")

price_next = int((liq * q96 * sqrtp_cur) // (liq * q96 + amount_in * sqrtp_cur))

print("New price:", (price_next / q96) ** 2)
print("New sqrtP:", price_next)
print("New tick:", price_to_tick((price_next / q96) ** 2))

amount_in = calc_amount0(liq, price_next, sqrtp_cur)
amount_out = calc_amount1(liq, price_next, sqrtp_cur)

print("ETH in:", amount_in / 10**18)
print("USDC out:", amount_out / 10**18)