-- Keybinds and the jump buffer. Controllers read actions, not raw key codes.

return {
	Forward = { Enum.KeyCode.W, Enum.KeyCode.Up },
	Back = { Enum.KeyCode.S, Enum.KeyCode.Down },
	Left = { Enum.KeyCode.A, Enum.KeyCode.Left },
	Right = { Enum.KeyCode.D, Enum.KeyCode.Right },
	Jump = { Enum.KeyCode.Space },
	Tune = { Enum.KeyCode.RightShift },
	Reset = { Enum.KeyCode.R },
	Cycle = { Enum.KeyCode.N },
	Menu = { Enum.KeyCode.M },
	JumpBuffer = 0.12,
}
