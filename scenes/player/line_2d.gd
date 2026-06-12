extends Line2D

##################################################
# 궤적을 그릴 최대 점의 개수 (선이 늘어날 최대 길이)
@export var max_points: int = 40
# 점과 점 사이의 시간 간격 (초 단위. 작을수록 선이 부드러워짐)
@export var time_step: float = 0.04

##################################################
# 부모 노드(Player)를 참조하여 캐릭터의 현재 조준 각도와 파워를 가져옴
@onready var player = get_parent()
# 프로젝트 설정에 등록된 2D 기본 중력 값을 가져와 저장
@onready var gravity: Vector2 = \
	Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))

##################################################
func _ready() -> void:
	width = 2.0								# 선의 두께 설정
	joint_mode = Line2D.LINE_JOINT_ROUND		# 꺾이는 관절 부분을 부드럽게 라운딩 처리
	begin_cap_mode = Line2D.LINE_CAP_ROUND	# 선이 시작되는 지점을 둥글게 처리
	end_cap_mode = Line2D.LINE_CAP_ROUND		# 선이 끝나는 지점을 둥글게 처리
	
	# 실시간으로 색상이 변하는 그라데이션 객체를 생성
	var new_gradient = Gradient.new()
	
	# 그라데이션이 끊기지 않고 부드러운 곡선 형태로 이어지도록 보간 모드를 설정
	new_gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	
	# 0번 위치(시작점): 민트색(#00ffcc), 불투명도 100%
	new_gradient.set_color(0, Color("#00ffcc"))
	
	# 끝점은 동일한 민트색이지만 불투명도를 0.0으로 주어 끝으로 갈수록 흐려지게 만듦
	new_gradient.set_color(1, Color("#00ffcc", 0.0))
	
	# 생성한 그라데이션 설정을 이 Line2D 노드에 최종 적용
	gradient = new_gradient

##################################################
func _process(_delta: float) -> void:
	# Player 노드 변수에 접근해 현재 조준 각도와 파워를 실시간으로 가져옴
	var angle_deg = player.aim_angle
	var power = player.aim_power
	
	# Player 코드와 동일하게 삼각함수(cos, sin) 연산을 위해 각도를 라디안 단위로 변환
	var angle_rad = deg_to_rad(angle_deg)
	# 포탄이 발사되는 순간의 초기 속도(방향 벡터 * 세기)를 계산
	var current_velocity = Vector2(cos(angle_rad), sin(angle_rad)) * power
	
	# 궤적 선이 시작될 기본 위치를 캐릭터의 중심 좌표로 잡음
	var start_pos = player.global_position
	# 만약 캐릭터에게 총구(Muzzle) 노드가 존재한다면
	if player.has_node("Muzzle"):
		# 더 정확한 연산을 위해 총구의 위치를 시작점으로 바꿈
		start_pos = player.get_node("Muzzle").global_position
	
	# 계산된 시작 위치와 초기 속도를 바탕으로 선을 그리는 함수를 호출
	update_trajectory(start_pos, current_velocity)

##################################################
# 벽에 닿기 전까지의 궤적을 계산하고 그려주는 핵심 함수
func update_trajectory(start_pos: Vector2, init_velocity: Vector2) -> void:
	# 새 선을 그리기 전에 이전 프레임에서 그려둔 점들을 지워 초기화
	clear_points()
	
	# 게임 월드의 물리 공간 상태(벽이 어디 있는지 등)를 검사할 수 있는 객체를 가져옴
	var space_state = player.get_world_2d().direct_space_state
	var current_pos = start_pos
	
	# 선의 첫 번째 시작점을 찍음
	# Line2D의 점들은 내 로컬 좌표 기준이므로 to_local() 함수로 월드 좌표를 로컬로 변환해야 함
	add_point(to_local(current_pos))
	
	# 설정해둔 최대 점의 개수만큼 반복문을 돌며 미래의 포탄 위치를 계산
	for i in range(1, max_points):
		# 현재 점이 위치할 미래의 시간(초)을 계산
		var t = i * time_step
		
		""" 등가속도 운동 공식 """
		# 미래의 위치 = 시작위치 + (초기속도 * 시간) + (0.5 * 중력 * 시간의 제곱)
		# 이 공식 덕분에 포탄이 중력을 받아 아름다운 포물선을 그리며 떨어지는 궤적이 계산됨
		var next_pos = start_pos + (init_velocity * t) + (0.5 * gravity * t * t)
		
		# current_pos에서 next_pos 사이에 벽이 있는지 가상의 Ray를 쏨
		var query: PhysicsRayQueryParameters2D = \
			PhysicsRayQueryParameters2D.create(current_pos, next_pos)
		# 광선이 발사대인 Player에게 부딪혀 선이 끊기는 것을 방지하기 위해 예외 처리
		query.exclude = [player.get_rid()]
		
		# Ray로 충돌 여부를 확인
		var result = space_state.intersect_ray(query)
		
		# 만약 무언가에 부딪혔다면
		if not result.is_empty():
			# 부딪힌 그 충돌 지점의 좌표를 가져옴
			var collision_pos = result.position
			# 충돌 지점까지만 마지막 점을 찍어주고
			add_point(to_local(collision_pos))
			# 벽을 뚫고 선이 더 그려지지 않도록 반복문을 강제로 종료(break)
			break
		
		# 아무것도 부딪히지 않았다면 정상적으로 계산된 다음 포물선 위치에 점을 이어 붙임
		add_point(to_local(next_pos))
		# 다음 루프 계산을 위해 현재 위치를 다음 위치로 업데이트
		current_pos = next_pos
