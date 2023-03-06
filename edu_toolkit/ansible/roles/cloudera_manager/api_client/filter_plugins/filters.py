class FilterModule(object):

  def filters(self):
    return {
      'to_ldap_type_enum': self.to_ldap_type_enum
    }

  def to_ldap_type_enum(self, s):
    if s == "AD":
      return "ACTIVE_DIRECTORY"
    return s.replace(" ","_").upper()

