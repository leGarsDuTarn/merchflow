class AddOptimizedDepartmentIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :job_offers, [:department_code, :start_date]
    add_index :job_offers, :department_code
  end
end
