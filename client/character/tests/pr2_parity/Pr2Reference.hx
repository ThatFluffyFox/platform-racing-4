import pr2.level.Level;
import pr2.level.Level.LevelBlock;
import pr2.level.Level.StatDefaults;
import pr2.level.Level.TilePosition;
import pr2.level.BlockType;
import pr2.gameplay.player.LocalPlayerController;
import pr2.gameplay.player.LocalPlayerInput;

// Runs PR2's LocalPlayerController on a JSON scenario and prints one line per frame.
class Pr2Reference {
	static function main() {
		for (path in Sys.args()) {
			Sys.println("# " + path);
			runScenario(path);
		}
	}

	static function runScenario(path:String) {
		var s:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
		var blocks:Array<LevelBlock> = [];
		var raw:Array<Dynamic> = s.blocks;
		for (b in raw) {
			// Scenarios use PR4 block ids. PR4 swaps the two rotate blocks.
			var id:Int = b[2];
			if (id == 22) id = 23 else if (id == 23) id = 22;
			blocks.push(new LevelBlock(b[0], b[1], LevelBlock.typeForCode(id + 99)));
		}
		var level = new Level("t", "t", 100, 100, 30, s.gravity, new StatDefaults(s.speed, 0.2 + s.accel / 60, 2 + s.jump / 40),
			new TilePosition(0, 0), new TilePosition(99, 99), blocks);
		var c = new LocalPlayerController(level, new pr2.gameplay.BlockController(level));
		c.resetPreRacePosition(s.x, s.y);
		// Optional held item, given as a PR4 item id.
		var pr4Items = [4 => 6, 5 => 1, 11 => 7, 12 => 5, 13 => 8, 14 => 4];
		if (s.item != null) c.grantItemForDebug(pr4Items.get(s.item));
		var inputs:Array<String> = s.inputs;
		for (i in 0...inputs.length) {
			var k = inputs[i];
			c.step(new LocalPlayerInput(k.indexOf("L") >= 0, k.indexOf("R") >= 0, k.indexOf("J") >= 0, k.indexOf("D") >= 0, k.indexOf("I") >= 0, k.indexOf("H") >= 0));
			Sys.println(i + " " + c.x + " " + c.y + " " + c.vx + " " + c.vy + " " + c.grounded + " " + c.crouching + " " + c.mode + " " + c.courseRotation);
		}
	}
}
