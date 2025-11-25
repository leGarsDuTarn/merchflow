require 'pagy/extras/bootstrap'   # Pour un style Bootstrap propre
require 'pagy/extras/overflow'    # Evite les erreurs quand on dépasse la dernière page

Pagy::DEFAULT[:items] = 6 # Valeur par défaut (tu peux changer)
Pagy::DEFAULT[:overflow] = :last_page
