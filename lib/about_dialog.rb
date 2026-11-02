# frozen_string_literal: true

require 'adwaita'

# AboutDialog is the application's about dialog.
#
# A direct port of upstream's gnomemusic/about.py: the same credits, the same
# links and the same licence.
module AboutDialog
  DEVELOPERS = [
    'Abhinav Singh', 'Adam Blanchet', 'Adrian Solom', 'Alberto Fanjul',
    'Alexander Mikhaylenko', 'Alireza Shabani', 'Alpesh Jamgade',
    'Andre Klapper', 'Andreas Nilsson', 'Apostol Bakalov', 'Arnel A. Borja',
    'Ashwani Singh Tanwar', 'Ashwin Mohan', 'Atharva Veer',
    'Automeris Naranja', 'Benoît Legat', 'Bilal Elmoussaoui', 'Billy Barrow',
    'Bruce Cowan', 'Carlos Garnacho', 'Carlos Soriano', 'Chinmay Gurjar',
    'Christophe van den Abbeele', 'Christopher Davis', 'Clayton G. Hobbs',
    'Divyanshu Vishwakarma', 'Dominique Leuenberger', 'Eslam Mostafa',
    'Elias Entrup', 'Erik Inkinen', 'Evan Nehring', 'Evandro Giovanini',
    'Ezike Ebuka', 'Fabiano Fidêncio', 'Feliks Weber', 'Felipe Borges',
    'Florian Darfeuille', 'Gaurav Narula', 'Georges Basile Stavracas Neto',
    'Guillaume Quintard', 'Gyanesh Malhotra', 'Harry Xie', 'Hugo Posnic',
    'Ishaan Shah', 'Islam Bahnasy', 'Jakub Steiner', 'James A. Baker',
    'Jan Alexander Steffens', 'Janne Körkkö', 'Jan-Michael Brummer',
    'Jean Felder', 'Jeremy Bicha', 'Jesus Bermudez Velazquez',
    'Jordan Petridis', 'Juan José González', 'Juan Suarez', 'Kainaat Singh',
    'Kalev Lember', 'Kevin Haller', 'Konstantin Pospelov', 'Koushik Sahu',
    'Lucy Coleclough', 'Marinus Schraal', 'Michael Catanzaro',
    'Mohanna Datta Yelugoti', 'Mpho Jele', 'Nick Richards', 'Niels De Graef',
    'Nikolay Yanchuk', 'Nils Reuße', 'Pablo Palácios', 'Phil Dawson',
    'Piotr Drąg', 'Prashant Tyagi', 'Rafael Coelho', 'Rashi Sah',
    'Rasmus Thomsen', 'Reuben Dsouza', 'Robert Greener', 'Sabri Ünal',
    'Sagar Lakhani', 'Sai Suman Prayaga', 'Sam Hewitt', 'Sam Thursfield',
    'Sambhav Kothari', 'Seif Lotfy', 'Shema Angelo Verlain',
    'Shivani Poddar', 'Shivansh Handa', 'Simon McVittie', 'Sophie Herold',
    'Subhadip Jana', 'Sumaid Syed', 'Suyash Garg', 'Tapasweni Pathak',
    'Tau Gärtli', 'Taylor Garcia', 'Tjipke van der Heide', 'Vadim Rutkovsky',
    'Veerasamy Sevagen', 'Vincent Cottineau', 'Vineet Reddy', 'Walt Shabani',
    'Weifang Lai', 'Yann Delaby', 'Yash Singh', 'Yosef Or Boczko',
  ].freeze

  DESIGNERS = ['Allan Day', 'Jakub Steiner', 'William Jon McCann'].freeze

  WEBSITE = 'https://apps.gnome.org/Music/'
  ISSUE_URL = 'https://gitlab.gnome.org/GNOME/gnome-music/-/issues/'

  # Shows the about dialog over the given parent.
  def self.show(app_id, version, parent)
    Adwaita::AboutDialog.new.tap do |about|
      about.application_name = 'Music'
      about.application_icon = app_id
      about.developer_name = 'The GNOME Project'
      about.developers = DEVELOPERS
      about.designers = DESIGNERS
      # Translators should localize the following string which will be
      # displayed at the bottom of the about box to give credit to the
      # translator(s).
      about.translator_credits = 'translator-credits'
      about.version = version
      about.website = WEBSITE
      about.issue_url = ISSUE_URL
      about.copyright = '© The GNOME Music Developers'
      about.license_type = Gtk::License::GPL_2_0
      about.present(parent)
    end
  end
end
