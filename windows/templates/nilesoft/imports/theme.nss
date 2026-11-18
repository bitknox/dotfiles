// {{ meta.name }} - Nilesoft Shell theme (rendered from palette.json by render.py)
// Reload: hold CTRL while right-clicking. Escape hatch: CTRL+WIN + right-click = native menu.
theme
{
	name = "modern"
	view = view.medium
	dark = true

	background
	{
		color = {{ mantle }}
		opacity = 96
		// 3 = acrylic: [3, tint, tint opacity]
		effect = [3, {{ base }}, 90]
	}

	item
	{
		opacity = 100
		radius = 2
		prefix = 1

		text
		{
			normal = {{ text }}
			normal.disabled = {{ overlay }}
			select = {{ cream }}
			select.disabled = {{ overlay }}
		}

		back
		{
			select = {{ surface1 }}
			select.disabled = {{ surface0 }}
		}

		border
		{
			select = {{ surface1 }}
			select.disabled = {{ surface0 }}
		}

		padding = [10, 6]
		margin = [4, 1]
	}

	border
	{
		enabled = true
		size = 1
		color = {{ surface1 }}
		opacity = 100
		radius = 3
		padding = [4, 6]
	}

	shadow
	{
		enabled = true
		size = 10
		color = {{ crust }}
		opacity = 45
		offset = 4
	}

	font
	{
		name = "{{ font.ui }}"
		size = 14
		weight = 4
	}

	separator
	{
		size = 1
		color = {{ surface1 }}
		opacity = 100
		margin = [12, 4]
	}

	symbol
	{
		chevron
		{
			normal = {{ subtext }}
			normal.disabled = {{ overlay }}
			select = {{ sakura }}
			select.disabled = {{ overlay }}
		}
		checkmark
		{
			normal = {{ spirit }}
			normal.disabled = {{ overlay }}
			select = {{ spirit }}
			select.disabled = {{ overlay }}
		}
		bullet
		{
			normal = {{ lavender }}
			normal.disabled = {{ overlay }}
			select = {{ sakura }}
			select.disabled = {{ overlay }}
		}
	}

	image
	{
		enabled = true
		// tints for the built-in glyph icons (icon.* in images.nss)
		color = [{{ sakura }}, {{ lavender }}, {{ spirit }}]
		align = 2
		gap = 8
	}
}
