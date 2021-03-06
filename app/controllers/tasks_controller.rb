class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :update, :destroy]

  # GET /tasks
  # GET /tasks.json
  def index
    if %w(Admin Movement).include?(current_user.role)
      @tasks = Task.all
    else
      @tasks = Task.all.where(publicity: 1, status: 1)
    end
  end

  # GET /tasks/1
  # GET /tasks/1.json
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new
  end

  # GET /tasks/1/edit
  def edit
  end

  # POST /tasks
  # POST /tasks.json
  def create
    @task = Task.new(task_params)
    @task.suggested_id = params[:suggested_id]

    respond_to do |format|
      if @task.save
        puts "****************************************"
        puts "task: #{@task.id}"
        if params[:private_group_id].present? && @task.personal?
          format.html {
            puts "Guide wants personal task"
            puts "before - task is: #{@task.status}"
            @task.approved!
            puts "after - task is: #{@task.status}"
            redirect_to assign_task_path(task: @task.id, group: params[:private_group_id])
          }
        else
          format.html { redirect_to root_path }
          format.json { render :show, status: :created, location: @task }
        end
      else
        format.html { render :new }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tasks/1
  # PATCH/PUT /tasks/1.json
  def update
    respond_to do |format|
      if @task.update(task_params)
        format.html { redirect_to root_path }
        format.json { render :show, status: :ok, location: @task }
      else
        format.html { render :edit }
        format.json { render json: @task.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tasks/1
  # DELETE /tasks/1.json
  def destroy
    @task.destroy
    respond_to do |format|
			if %w(Movement Admin).include?(current_user.role)
      format.html { redirect_to tasks_url, notice: 'Task was successfully destroyed.' }
			format.json { head :no_content }
			else
				format.html { redirect_to root_path }
			end
    end
  end

  def assign_task
    @task = Task.find(params[:task])
    if params[:group].present?
      @group = Group.find(params[:group])
      @group.kids.each do |k|
        k.tasks << @task if k.tasks.exclude?(@task)
      end
      @task.approved!
    else
      current_user.tasks << @task if current_user.tasks.exclude?(@task)
    end
    redirect_to root_path
  end

  def change_progress
    puts "****************************************"
    puts "Change Progress"
    if params[:kid_id].present?
			kid = User.find(params[:kid_id])
			my_task = kid.my_tasks.find_by(task_id: params[:task_id])
			puts "kid: #{my_task.user.name}"
			puts "task: #{my_task.task.name} from #{my_task.progress}"
			if params[:revert].present?
				my_task.progress = "in_progress"
			else
				my_task.progress = "approved"
				kid.update(score: kid.score + my_task.task.score)
				kid.groups.where("my_groups.role = 0").each do |g|
					g.update(score: g.score + my_task.task.score)
					g.branch.update(score: g.branch.score + my_task.task.score)
					g.branch.region.update(score: g.branch.region.score + my_task.task.score)
					# g.branch.region.movement.update(score: g.branch.region.movement.score + my_task.task.score)
				end
			end
    else
			my_task = current_user.my_tasks.find_by(task_id: params[:task_id])
			if params[:remove].present?
				my_task.delete
			else
				puts "task: #{my_task.task.name} from #{my_task.progress}"
				my_task.progress = "done"
			end
    end
    my_task.save unless params[:remove].present?
    puts "to #{my_task.progress}"
    redirect_to root_path
  end

  def approve_task
    Task.find(params[:task_id]).approved!
    redirect_to tasks_path
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_task
      @task = Task.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def task_params
      params.require(:task).permit(:name, :score, :description, :publicity, :status, :difficulty, :age)
    end
end
