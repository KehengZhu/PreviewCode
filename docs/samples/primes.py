"""Find prime numbers with the sieve of Eratosthenes."""

from dataclasses import dataclass
from math import isqrt


@dataclass
class Sieve:
    limit: int

    def primes(self) -> list[int]:
        """Return every prime up to and including `limit`."""
        if self.limit < 2:
            return []
        is_prime = [True] * (self.limit + 1)
        is_prime[0] = is_prime[1] = False
        for n in range(2, isqrt(self.limit) + 1):
            if is_prime[n]:
                # Cross out every multiple of n, starting at n squared
                for multiple in range(n * n, self.limit + 1, n):
                    is_prime[multiple] = False
        return [n for n, prime in enumerate(is_prime) if prime]


def twin_primes(primes: list[int]) -> list[tuple[int, int]]:
    return [(p, q) for p, q in zip(primes, primes[1:]) if q - p == 2]


if __name__ == "__main__":
    found = Sieve(limit=100).primes()
    print(f"{len(found)} primes below 100: {found}")
    print("Twin primes:", twin_primes(found))
