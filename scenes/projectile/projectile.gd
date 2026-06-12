extends RigidBody2D

##################################################
func _ready() -> void:
	# 물리 엔진이 완벽하게 준비된 뒤에 설정을 적용
	await get_tree().physics_frame
	
	# 처음에는 충돌 감지 모니터를 꺼둠
	contact_monitor = true
	# 동시에 감지할 수 있는 최대 충돌 횟수를 1개로 제한
	max_contacts_reported = 1
	
	# 프로젝트 기본 공기저항 값 대신, 이 투사체만의 고유한 저항 모드를 사용하겠다고 설정
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	# 공기저항을 0.0으로 만들어, 날아가는 동안 속도가 수평 방향으로 줄어들지 않고 일정하게 만듦
	linear_damp = 0.0
	
	# 내가 누구인가?
	set_collision_layer_value(1, false)	# 1번 레이어에서 나를 제외
	set_collision_layer_value(2, true)	# 나를 2번 레이어로 지정
	
	# 누구랑 부딪힐 것인가?
	set_collision_mask_value(1, true)	# 1번 레이어와는 닿았을 때 충돌을 감지
	set_collision_mask_value(2, false)	# 2번 레이어끼리는 부딪히지 않고 통과
	
	# 다른 물리 바디와 충동 시, body_entered 시그널을 _on_body_entered() 함수와 연결
	body_entered.connect(_on_body_entered)

##################################################
# 무언가와 부딪히는 순간 엔진에 의해 자동으로 호출되는 콜백 함수
func _on_body_entered(_body: Node2D) -> void:
	# 포탄이 무언가에 닿았으므로 메모리에서 완전히 삭제
	queue_free()

##################################################
# 외부(Player 스크립트 등)에서 포탄을 스폰한 뒤, 날려 보낼 속도와 방향을 주입해 주는 함수
func launch(initial_velocity: Vector2) -> void:
	# RigidBody2D 고유 변수인 linear_velocity에 속도를 대입하여
	# 포탄을 물리적으로 물리엔진 안에서 출발시킴
	linear_velocity = initial_velocity
