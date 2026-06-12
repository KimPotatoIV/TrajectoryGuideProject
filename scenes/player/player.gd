extends CharacterBody2D

##################################################
# 방향과 상태를 정하는 enum
enum Direction { LEFT, RIGHT }
enum State { IDLE, RUN }

##################################################
const RUN_SPEED: float = 100.0			# 캐릭터의 이동 속도
const AIM_SPEED: float = 135.0			# 조준선(상하)이 움직이는 속도
const POWER_CHANGE_SPEED: float = 300.0	# 발사 세기(좌우)가 조절되는 속도
const MIN_POWER: float = 150.0			# 발사 최소 세기
const MAX_POWER: float = 600.0			# 발사 최대 세기
const MIN_AIM_ANGLE_LEFT: float = -180.0	# 좌측 조준 최소 각도
const MAX_AIM_ANGLE_LEFT: float = -100.0	# 좌측 조준 최소 각도
const MIN_AIM_ANGLE_RIGHT: float = -80.0	# 우측 조준 최소 각도
const MAX_AIM_ANGLE_RIGHT: float = 0.0	# 우측 조준 최대 각도

# 발사할 투사체 씬 파일을 미리 메모리에 로드
const PROJECTILE_SCENE: PackedScene = \
	preload("res://scenes/projectile/projectile.tscn")

var current_direction: Direction = Direction.RIGHT	# 현재 바라보는 방향
var current_state: State = State.IDLE				# 현재 상태
var aim_angle: float = -45.0							# 현재 조준 각도
var aim_power: float = 300.0							# 현재 발사 세기

# 애니메이션 제어용
@onready var anim_sprite_node: AnimatedSprite2D = $AnimatedSprite2D
# 총구(투사체 생성 위치)
@onready var muzzle_node: Marker2D = $Muzzle

##################################################
func _physics_process(delta: float) -> void:
	# 바닥에 닿아있지 않다면
	if not is_on_floor():
		# 중력 적용
		velocity += get_gravity() * delta
	
	# 이동 입력 처리
	var direction: float = Input.get_axis("ui_left", "ui_right")
	# 이동 키를 누르고 있다면
	if direction != 0.0:
		# 그 방향으로 속도를 지정
		velocity.x = direction * RUN_SPEED
		# 상태를 RUN으로 바꿈
		current_state = State.RUN
		# 입력 방향에 따라 바라보는 방향 변수 업데이트
		if direction > 0.0:
			current_direction = Direction.RIGHT
		else:
			current_direction = Direction.LEFT
	else:
		# 이동 키를 떼면 마찰력이 작용하듯 속도를 0으로 부드럽게 줄여줌
		velocity.x = move_toward(velocity.x, 0, RUN_SPEED)
		# 상태를 IDLE로 바꿈
		current_state = State.IDLE
	
	# 방향과 상태를 업데이트
	set_direction_and_state(current_direction, current_state)
	
	# 발사 입력 처리
	if Input.is_action_just_pressed("ui_accept"):
		shoot()
	
	# 조준 각도와 파워 변경 입력을 처리
	handle_aiming(delta)
	
	# 계산된 velocity를 바탕으로 캐릭터를 움직이게 만듦
	move_and_slide()

##################################################
# 캐릭터의 방향 전환(스프라이트 좌우 반전 및 총구 위치 조정)과 애니메이션 재생을 담당
func set_direction_and_state(dir_value: Direction, state_value: State) -> void:
	# 왼쪽을 바라볼 때
	if dir_value == Direction.LEFT:
		# 기존에 오른쪽을 보고 있었다면
		if not anim_sprite_node.flip_h:
			# 조준 각도 뒤집기 (오른쪽 위 -> 왼쪽 위)
			aim_angle = 180.0 - aim_angle
			# 총구 위치도 왼쪽으로 대칭 이동
			if muzzle_node.position.x > 0:
				muzzle_node.position.x *= -1
		# 스프라이트 방향 전환 처리
		anim_sprite_node.flip_h = true
	# 오른쪽을 바라볼 때
	elif dir_value == Direction.RIGHT:
		# 기존에 왼쪽을 보고 있었다면
		if anim_sprite_node.flip_h:
			# 조준 각도 뒤집기 (왼쪽 위 -> 오른쪽 위)
			aim_angle = 180.0 - aim_angle
			# 총구 위치도 오른쪽으로 대칭 이동
			if muzzle_node.position.x < 0:
				muzzle_node.position.x *= -1
		# 스프라이트 방향 전환 처리
		anim_sprite_node.flip_h = false
	
	# wrapf() 함수를 사용해 -180도 ~ 180도 범위를 벗어나면 한 바퀴 돌아 제자리로 오게 제어
	aim_angle = wrapf(aim_angle, -180.0, 180.0)
	
	# 상태에 맞는 애니메이션 재생 (대기 또는 달리기)
	match state_value:
		State.IDLE:
			anim_sprite_node.play("idle")
		State.RUN:
			anim_sprite_node.play("run")

##################################################
# 사용자의 조작에 따라 조준 각도와 발사 파워를 실시간으로 조절하는 함수
func handle_aiming(delta: float) -> void:
	# 조준 각도 제어
	var angle_input: float = \
		Input.get_axis("ui_aim_angle_up", "ui_aim_angle_down")
	if angle_input != 0.0:
		# 캐릭터가 보는 방향에 따라 각도 계산을 반대로 뒤집음
		var direction_sign: float = 1.0
		if current_direction == Direction.LEFT:
			direction_sign = -1.0
		
		# delta를 곱해 항상 일정한 속도로 각도가 변하게 함
		aim_angle += angle_input * AIM_SPEED * delta * direction_sign
	
	# clamp() 함수로 발사 각도를 부채꼴 범위로 제한
	if current_direction == Direction.RIGHT:
		aim_angle = clamp(aim_angle, MIN_AIM_ANGLE_RIGHT, MAX_AIM_ANGLE_RIGHT)
	else:
		aim_angle = clamp(aim_angle, MIN_AIM_ANGLE_LEFT, MAX_AIM_ANGLE_LEFT)
	
	# 발사 파워 제어
	var power_input: float = \
		Input.get_axis("ui_aim_power_left", "ui_aim_power_right")
	if power_input != 0.0:
		# 캐릭터가 보는 방향에 따라 파워 계산을 반대로 뒤집음
		var power_sign: float = 1.0
		if current_direction == Direction.LEFT:
			power_sign = -1.0
		
		# 파워를 증감 시키고
		aim_power += power_input * POWER_CHANGE_SPEED * delta * power_sign
		# 설정한 최소/최대치 범위 내로 가둠
		aim_power = clamp(aim_power, MIN_POWER, MAX_POWER)

##################################################
# 실제로 투사체 오브젝트를 생성하고 날려 보내는 함수
func shoot() -> void:
	# 프리로드 해둔 씬의 인스턴스(복사본)를 생성
	var projectile = PROJECTILE_SCENE.instantiate()
	
	# 생성된 투사체의 위치를 현재 캐릭터의 총구(Muzzle) 월드 좌표와 일치시킴
	projectile.global_position = muzzle_node.global_position
	
	# 삼각함수(cos, sin)는 라디안 단위를 사용하므로 
	# 도 단위였던 aim_angle을 deg_to_rad()로 먼저 변환
	var angle_rad = deg_to_rad(aim_angle)
	# cos(x)는 X축 방향 벡터, sin(x)는 Y축 방향 벡터를 만들어냄
	# 이 방향 벡터(길이가 1인 방향)에 aim_power(세기)를 곱해 최종 속도(Vector2)를 완성
	var final_velocity = Vector2(cos(angle_rad), sin(angle_rad)) * aim_power
	
	# 투사체를 현재 실행 중인 메인 게임 씬의 자식으로 등록하여 화면에 보이게 함
	get_tree().current_scene.add_child(projectile)
	
	# 투사체 스크립트의 launch() 함수를 호출하여 속도를 주입하고 날려 보냄
	projectile.launch(final_velocity)
