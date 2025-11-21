# Configuration du comportement des erreurs de formulaire dans Rails
# Cette procédure est appelée automatiquement par Rails pour chaque champ
# qui contient une erreur de validation

ActionView::Base.field_error_proc = proc do |html_tag, _instance|

  # On vérifie si la balise HTML est un champ de formulaire (input, textarea, select)
  # et non un label. Cela évite de styliser les labels avec la classe d'erreur.
  if html_tag =~ /<(input|textarea|select)/

    # On assigne directement le résultat du conditionnel à la variable new_tag
    # Cas 1 : La balise possède déjà un attribut "class"
    # On ajoute simplement notre classe "is-invalid-orange" aux classes existantes
    # Cas 2 : La balise n'a pas encore d'attribut "class"
    # On ajoute un nouvel attribut class avec notre classe d'erreur
    new_tag = if html_tag =~ /class="/
                html_tag.sub('class="', 'class="is-invalid-orange ')
              else
                html_tag.sub(/\/>|>/, ' class="is-invalid-orange"\0')
              end

    # On retourne la nouvelle balise modifiée comme HTML sécurisé
    new_tag.html_safe

  else
    # Si c'est un label ou un autre élément, on le retourne tel quel sans modification
    html_tag.html_safe
  end
end
