require "gosu"
require_relative "defstruct"
require_relative "vector"


GRAVITY = Vector[0,100]
UPVEL = Vector[0,50]
THROTTLE = Vector[100,0]
OBSTACLE_SPEED = 150
OBSTACLE_SPAWN_INTERVAL = 3
OBSTACLE_GAP = 100
DEATH = Vector[75, 300]
ROTATE = 360
RESTART_INTERVAL = 3

Rect =DefStruct.new{{
	pos: Vector[0,0],
	size: Vector[0,0]
	}}.reopen do
		def minX; pos.x; end
		def minY; pos.y; end
		def maxX; pos.x + size.x;end
		def maxY; pos.y + size.y;end
	end

Finger = DefStruct.new{{
	pos: Vector[0,0],
	playerCrossed: false,
	}}

GameState = DefStruct.new{{
	started: false,
	scroll_x: 0,
	score: 0,
	alive: true,
	playerPosition: Vector[20, 250],
	playerVelocity: Vector[0, 0],
	playerRotate: 0,
	obsticles: [],
	obsticle_countdown: OBSTACLE_SPAWN_INTERVAL,
	restartCountdown: RESTART_INTERVAL,
}}

class GameWindow < Gosu::Window
	def initialize(*args)
		super
		@font = Gosu::Font.new(self, Gosu.default_font_name, 40)
		@images = {
			background: Gosu::Image.new(self, "sky.png", false),
			foreground: Gosu::Image.new(self, "foreground.png", true),
			plane: Gosu::Image.new(self,"plane100px.png", false),
			upFing: Gosu::Image.new(self,"finger-up.png", false),
			#downFing: Gosu::Image.new(self,"finger-down.png", false),
		}
		@state = GameState.new
	end

	def button_down(button)
		case button
		when Gosu::KbEscape then close
		when Gosu::KbUp 
			@state.playerVelocity.set!(-UPVEL) if @state.alive
			@state.started = true
		when Gosu::KbRight then @state.playerVelocity.set!(THROTTLE) if @state.alive
		when Gosu::KbLeft then @state.playerVelocity.set!(-THROTTLE) if @state.alive
		end
	end

	def update
		dtime = update_interval / 1000.00

		@state.scroll_x += dtime*OBSTACLE_SPEED*0.5
		if @state.scroll_x > @images[:foreground].width
			@state.scroll_x =0
		end

		return unless @state.started

		@state.playerVelocity += dtime*GRAVITY
		@state.playerPosition += dtime*@state.playerVelocity

		@state.playerVelocity += dtime*THROTTLE
		@state.playerPosition += dtime*@state.playerVelocity

		@state.obsticle_countdown -= dtime
		if @state.obsticle_countdown <= 0
			@state.obsticles << Finger.new(pos: Vector[width, rand(50...200)])
			@state.obsticle_countdown += OBSTACLE_SPAWN_INTERVAL
		end

		@state.obsticles.each do |obstl|
			obstl.pos.x -= dtime*OBSTACLE_SPEED
			if obstl.pos.x < @state.playerPosition.x && !obstl.playerCrossed && @state.alive
				@state.score += 1
				obstl.playerCrossed = true
			end
		end

		@state.obsticles.reject! { |obstl| obstl.pos.x < -@images[:upFing].width}

		if @state.alive && player_is_colliding?
			@state.alive = false
			@state.playerVelocity.set!(DEATH)
		end

		unless @state.alive
			@state.playerRotate += dtime*ROTATE
			@state.restartCountdown -= dtime
			if @state.restartCountdown <= 0
				restartGame
			end
		end
	end

	def restartGame
		@state = GameState.new(scroll_x: @state.scroll_x)

	end

	def player_is_colliding?
		playerR = playerRect
		return true if obstRects.find { |obstlR| rectsIntersec?(playerR, obstlR) }
		not rectsIntersec?(playerR, Rect.new(pos: Vector[0, 0], size: Vector[width, height]))
	end

	def rectsIntersec?(r1, r2)
		return false if r1.maxX < r2.minX
		return false if r1.minX > r2.maxX

		return false if r1.minY > r2.maxY
		return false if r1.maxY < r2.minY

		true
	end

	def draw
		@images[:background].draw(0,0,0)
		#@images[:downFing].draw(100,-100,0)
		imgY = @images[:upFing].height
		@state.obsticles.each do |obstl|
			@images[:upFing].draw(obstl.pos.x, imgY - obstl.pos.y + 100, 0)
			scale(1, -1) do
				@images[:upFing].draw(obstl.pos.x, -imgY + obstl.pos.y , 0)
			end
		end
		@images[:plane].draw_rot(@state.playerPosition.x,@state.playerPosition.y,0, @state.playerRotate,0,0)
		@images[:foreground].draw(-@state.scroll_x,300,0)
		@images[:foreground].draw(-@state.scroll_x + @images[:foreground].width,300,0)

		@font.draw_rel(@state.score,width/2,35,0, 0.5, 0.5)

		#debug_draw
	end

	def playerRect
		playerRect = Rect.new(
			pos: @state.playerPosition,
			size: Vector[@images[:plane].width, @images[:plane].height]
			)
	end

	def obstRects
		imgY = @images[:upFing].height
		obsSize =  Vector[@images[:upFing].width, @images[:upFing].height]
		
		@state.obsticles.flat_map do |obstl|
			top = Rect.new(pos: Vector[obstl.pos.x + 10, -obstl.pos.y - 15],size: obsSize)
			bot = Rect.new(pos: Vector[obstl.pos.x + 10, imgY -obstl.pos.y + 110],size: obsSize)
			[top, bot]
		end
	end

	def debug_draw
		color = player_is_colliding? ? Gosu::Color::RED : Gosu::Color::GREEN
		draw_debug_rect(playerRect, color)
		obstRects.each do |obstl_rectan|
			draw_debug_rect(obstl_rectan)
		end

	end
	def draw_debug_rect(rect, color = Gosu::Color::GREEN)
		x = rect.pos.x
		y = rect.pos.y
		w = rect.size.x
		h = rect.size.y
		points = [
			Vector[x,y],
			Vector[x + w,y],
			Vector[x + w, y + h],
			Vector[x, y + h]
		]

		points.each_with_index do |p1, indx|
			p2 = points[(indx + 1) % points.size]
			draw_line(p1.x, p1.y, color, p2.x, p2.y, color)
		end
	end
end

window = GameWindow.new(700, 500, false)
window.show