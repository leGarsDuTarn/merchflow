ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
  errors = Array(instance.error_message).join(', ')

  # Ajoute une classe CSS "is-invalid-orange"
  if html_tag =~ /^<input|^<textarea|^<select/
    new_tag = html_tag.sub(/class="/, 'class="is-invalid-orange ')
  else
    new_tag = html_tag
  end

  <<-HTML.html_safe
    <div class="field-with-errors">
      #{new_tag}
      <p class="error-text mt-1 mb-0">#{errors}</p>
    </div>
  HTML
end
