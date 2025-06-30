
# Configure storage class for osdu
resource "kubernetes_storage_class" "osdu-ir-storage-gp2-ebs" {
  metadata {
    name = "osdu-ir-storage-gp2-ebs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  parameters = {
    type   = "gp2"
    fsType = "ext4"
  }

  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = "true"

}
