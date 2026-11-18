---
tags: [physics, review]
status: draft
---

# Damped Harmonic Oscillator

A mass on a spring with friction obeys $m\ddot{x} + c\dot{x} + kx = 0$. With $\gamma = c/2m$ and $\omega_0 = \sqrt{k/m}$, the solution is

$$
x(t) = A\, e^{-\gamma t} \cos\!\left(\sqrt{\omega_0^2 - \gamma^2}\; t + \varphi\right).
$$

> [!tip] Regimes
> The sign of $\omega_0^2 - \gamma^2$ decides whether the motion ==oscillates== or decays.

| Regime | Condition | Behavior |
|---|---|---|
| Underdamped | $\gamma < \omega_0$ | Decaying oscillation |
| Critically damped | $\gamma = \omega_0$ | Fastest return, no overshoot |
| Overdamped | $\gamma > \omega_0$ | Slow exponential decay |

```python
import numpy as np
t = np.linspace(0, 10, 500)
x = np.exp(-0.3 * t) * np.cos(2 * t)
```

- [x] Derive the characteristic equation
- [ ] Add the driven case, see [[Resonance]] #todo
